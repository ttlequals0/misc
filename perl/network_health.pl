#!perl

use feature qw/say switch/;
use Net::Ping;
use Getopt::Long;
use Term::ANSIColor qw/:constants/;

sub scrub(\$)
{
    my $sref = shift;
    $$sref =~ s/[\r\n]//g;
    return $$sref;
}

sub expand_flags
{
    my $fr = shift;
    scrub $fr;
    $fr = hex $fr;
    my %flags = ( up          => $fr & 0x1 && 1
                , broadcast   => $fr & 0x2 && 1
                , debug       => $fr & 0x4 && 1
                , loopback    => $fr & 0x8 && 1
                , ppp         => $fr & 0x10 && 1
                , notrailers  => $fr & 0x20 && 1
                , running     => $fr & 0x40 && 1
                , noarp       => $fr & 0x80 && 1
                , promiscuous => $fr & 0x100 && 1
                , allmulti    => $fr & 0x200 && 1
                , loadmaster  => $fr & 0x400 && 1
                , loadslave   => $fr & 0x800 && 1
                , multi       => $fr & 0x1000 && 1
                , portsel     => $fr & 0x2000 && 1
                , automedia   => $fr & 0x4000 && 1
                , dynamic     => $fr & 0x8000 && 1
                , lowerup     => $fr & 0x10000 && 1
                , dormant     => $fr & 0x20000 && 1
                , echo        => $fr & 0x40000 && 1
                );

    return %flags;
}

sub prefix2bin
{
    my $prefix = shift;
    my $raw = 0;
    for(1..$prefix)
    {
        $raw >>= 1 if $raw;
        $raw += 0x8000_0000;
    }

    return $raw;
}

sub bin2octets
{
    my $bin = shift;
    my $octets = '';
    $octets = ($bin & 0xFF00_0000) >> 24;
    $octets .= '.';
    $octets .= ($bin & 0x00FF_0000) >> 16;
    $octets .= '.';
    $octets .= ($bin & 0x0000_FF00) >> 8;
    $octets .= '.';
    $octets .= $bin & 0x0000_00FF;

    return $octets;
}

sub octets2bin
{
    my $octets = shift;
    my $bin = 0;
    my $spot = 24;
    foreach(split /\./, $octets)
    {
        $bin |= $_ << $spot;
        $spot -= 8;
    }

    return $bin;
}

sub prefix2octets
{
    my $in = shift;
    return bin2octets( prefix2bin($in) );
}

sub first_host($$)
{
    my($addr,$mask) = @_;
    return bin2octets( (octets2bin($addr) & octets2bin($mask)) + 1 );
}

sub HELP_MESSAGE
{
    print <<"EOM";
$0 - Test connectivity and display interface information

--expect   Comma separated list of interfaces you expect to be active
--quiet    Only show messages for failed tests (overrides details and map)
--details  Show interface details
--map      Show interface connection map
--help     Show this message

EOM
}

#======================================================================

my %opts = ( expect  => ''
           , quiet   => 0
           , details => 0
           , map     => 0
           , help    => 0
           );

Getopt::Long::GetOptions( \%opts
                        , 'expect=s'
                        , 'quiet!'
                        , 'details!'
                        , 'map!'
                        , 'help!'
                        );
if($opts{help})
{
    HELP_MESSAGE();
    exit 1;
}
if($opts{quiet})
{
    $opts{details} = 0;
    $opts{map}     = 0;
}
my @expectations = split /,/, $opts{expect};


my %ifs = ();

#Get static info
foreach(</sys/class/net/*>)
{
    my %if;
    my $name = `basename $_`;
    scrub $name;

    #ethtool
    foreach(qw/driver version firmware-version bus-info/)
    {
        next if $name eq 'lo';
        my $line = `ethtool -i $name | grep $_ | awk '{print \$2}'`;
        scrub $line;
        $if{$_} = $line;
    }

    #sys
    $if{mac} = `cat $_/address`;
    scrub $if{mac};
    $if{flags} = { expand_flags(`cat $_/flags`) };

    #ip
    if($if{flags}{up})
    {
        my($ip,$prefix) = (split '/', `ip -f inet addr show dev $name |
                                       grep inet |
                                       awk '{print \$2}'`);
        $if{num_ip} = `ip -f inet addr show dev $name |
                         grep inet |
                         wc |
                         awk '{print \$1}'`;
        scrub $if{num_ip};
        $if{ip} = $ip;
        $if{mask} = prefix2octets($prefix);
    }

    $ifs{$name} = \%if;
}

#Check for correct paths
my $p = Net::Ping->new('icmp', 1);
while( my($k,$v) = each %ifs )
{
    next if $k eq 'lo' || !($v->{flags}->{up});
    my $first_hop = first_host($v->{ip}, $v->{mask});
    $v->{def_resp} = $p->ping( $first_hop );

    my $line = `arp | grep $first_hop`;
    scrub $line;
    my($arp_ip,$arp_mac,$arp_name) = $line
        =~  m/^([\d\.]+)\s*(?:ether|)\s*([A-Fa-f0-9:]+|incomplete)\s*\w\s*(\w+)/;
    $v->{switch_mac} = $arp_mac;
    if( $arp_name eq $k )
    {
        $v->{arp_valid} = 1;
    }
}

my $all_sane = 1;
while( my($k,$v) = each %ifs )
{
    my $sane = 1;
    next if $k eq 'lo';
    if( ! $v->{flags}->{up}  )
    {
        if( grep { $_ eq $k } @expectations )
        {
            print "$k: \t";
            say RED 'Interface not active';
            print RESET;
            $sane = $all_sane = 0;
        }
        next;
    }

    unless($v->{num_ip} <= 1)
    {
        print "$k: \t";
        say RED 'Interface has more than one IP';
        print RESET;
        $sane = 0;
    }
    unless($v->{def_resp})
    {
        print "$k: \t";
        say RED 'Interface next hop does not reply to echo';
        print RESET;
        $sane = 0;
    }
    unless($v->{arp_valid})
    {
        print "$k: \t";
        say RED 'ARP entry incorrect for interfaces first hop';
        print RESET;
        $sane = 0;
    }
    $sane
        ? ( ! $opts{quiet} && say "$k: \t" . GREEN "OK" )
        : ($all_sane = $sane);
    print RESET;
}
say;

exit !$all_sane unless( $opts{details} || $opts{map} );
while( my($k,$v) = each %ifs )
{
    if($opts{details} || $opts{map})
    {
        unless( $v->{flags}->{up} )
        {
            print "$k:  ";
            ( scalar @expectations && grep {$_ eq $k} @expectations )
                ? say RED 'DOWN'
                : say YELLOW 'DOWN';
        }
        else
        {
            say "$k:  " . GREEN 'UP';
        }
        print RESET;
    }

    if($opts{details})
    {
        say '  Driver:      ' . $v->{driver} || '';
        say '  Firmware:    ' . $v->{'firmware-version'} || '';
        say '  PCI address: ' . $v->{'bus-info'} || '';
        say '  MAC address: ' . $v->{mac} || '';
        say '  IP address:  ' . $v->{ip} || '';
        say '  Subnet mask: ' . $v->{mask} || '';
    }

    if($opts{map})
    {
        say '  '
            . ( $v->{'bus-info'} || '?' )
            . CYAN ' --> ' . RESET
            . ( $v->{mac} || '?' )
            . CYAN ' --> ' . RESET
            . ( $v->{ip} || '?' )
            . CYAN ' <-- ' . RESET
            . ( $v->{switch_mac} || '?' )
            . CYAN ' <-- ' . RESET
            . ( $v->{switch_port} || '?' );
    }

    if($opts{details} || $opts{map})
    {
        say;
    }
}

exit !$all_sane;
