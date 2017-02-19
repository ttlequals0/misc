#!/usr/bin/perl -w
# script will extract data from sh cdp ne de and produce following report:
# router/switch name, local ip, local port, remote name, remote,port, remote device type, remote device ios ver, remote device ios image, remote device vtp domain name (if any)
# 
@file_list = `ls -1 /data/engineering/networking/cdp_rep/output/*out`;

# 3 output files will be created:  
#  1. ports.csv
#            device_name,port,label
#  2. cdp_neighbor.csv
#            device_name,port,remote_name,remote_ip,remote_port
#  3. router_adj.csv
#            router,port,remote_ip

$file ="ports.csv";
open(PO, ">$file") || die "cant open $file file \n";
$file ="cdp_neighbor.csv";
open(CDP,">$file") || die "cant open $file file \n";
$file ="router_adj.csv";
open(ADJ,">$file") || die "cant open $file file \n";

while($#file_list >= 0)
   {
    # scan for begingining 
    $next_file = pop(@file_list);
    chomp $next_file;
    open(IN,"$next_file") or die "cant open $next_file file \n";
    @lines = <IN>;
    close(IN);
    @lines = pre_process_file(@lines);
    process_file(@lines);

   }

# --------------------------- process_file ---------------------------
sub process_file
{
my @lines = @_;

my $line = shift(@lines);
my $prot;
my $stat ="";
# determine device prompt

while($#lines >3)
   {
#  while(($line !~ /^Interface/) && ($line !~/\>sh adj/) && ($#lines >1))
   while(($line !~ /^Interface/) && ($line !~/\>sh\s.*/) && ($#lines >1))
      {
       if($line =~ /\>/)
         {
         ($device) = split(/\>/,$line);
         }
      $line = shift(@lines);
      }
if(!(defined($device)))
  {
  print "device not defined: $next_file\n";
  die;
  }
   if($line =~ /^Interface/)
     {

       # we have port info now
      ($pos1,$pos2,$pos3) = get_pos($line);
print "$device this ine should start with Interface: \n$line";
print "POS=> $pos1,$pos2,$pos3\n";
       $port = (split(/\s+/,$line))[1];
       $port =~ s/\,//g;
       $port = norm_int($port); 
    
      while(($line !~ /\>sh/) && ($#lines > 2))
       { 
       chomp $line;
       $stat = substr($line,$pos1,($pos2-$pos1));

       if(!(defined($stat)))
         {
         print "line is $line\n";
          die;
         }
       $stat =~ s/\s+//g;
       $prot = substr($line,$pos2,($pos3-$pos2));
       $prot =~ s/\s+//g;
       $desc = substr($line,$pos3);
       $desc =~ s/\s+//g;
       print PO "$device,$port,$stat,$prot,$desc\n";
 print  "$device,$port,$stat,$prot,$desc\n";
       $line = shift(@lines);
       }
     } # end if line = ^Interface
   # port info is between >sh interface and '>sh adj'
   # skip untill first record
   while(($line !~/^Protocol/) && ($line !~ /\>sh cdp/) && ($#lines >2))
     {
     $line = shift(@lines);
     # print $line;
     } 
   if(($line =~ /\>sh cdp/) || ($#lines < 2)) {last;} 
   $line = shift(@lines);
   while(($line !~/\>sh/) && ($#lines >1))
     {
     ($b,$int,$neig) = split(/\s+/,$line); 
     $int = norm_int($int);
     $neig =~ s/\(\d+\)//g;
     print ADJ "$device,$int,$neig\n";
     print  "$device,$int,$neig\n";
     $line = shift(@lines);
     
     }
   last;
  }
  while($#lines > 3)
    { 
   # seek forst line containing "----"
    while(($line !~ /--/) && ($#lines >2))
     { 
     $line = shift(@lines);

     }
    # now we scan to find device ID
     if (!(defined($line))) {last;}
     while(($line !~ /Device ID/) && ($#lines >2))
         {
         $line = shift(@lines);
    
         }
     # $line contains Device_ID
     if (!(defined($line))) {last;}
   $line =~ s/[^[:print:]]//g;
   print "DEV => $device";
   print "LINE ==> $line";
     chomp $line;
     $rdevice = extract_name($line);

   print "Value => ", $rdevice," \n";
   
     while(($line !~ /IP address/) && ($#lines >1))
        {
         $line = shift(@lines);
        }
     # ip addresse(s)
         chomp $line;
     ($b,$ip_rem) = split(/IP address: /,$line);
     if(defined($ip_rem))
       {
        $ip_rem =~ s/[^ -~]+//g;
       }
     else
      {
       print "cant find ip_rem $line\n";
       $ip_rem ="";
      }
     # initial value of vtp in case domain is not defined 
     $vtp_domain = "";
    $line = shift(@lines);
    while(($line !~ /--/) && ($#lines >2))
        {
        chomp $line;
        if($line =~ /Platform:/)
          {
          (@elements) = split(/\,|\:/,$line);
          $platform = $elements[1];
          $platform =~ s/^\s+//;
          $cap = pop(@elements);
          chomp $cap;
          $cap =~ s/^\s+//;
          $cap =~ s/\s+$//;
          }
        if($line =~ /^Interface:/)
          {

          $line =~ s/\,//g;
          (@elements) = split(/\s+/,$line);
#print "Looning for Interface line is => @elements\n";
          $loc = norm_int($elements[1]);
          $rem = norm_int($elements[$#elements]);
          }
        if($line =~ /Software.*Version/i)
          {
          ($image,$os_ver) = get_ios_info($line);
          }
        #while(($line !~ /VTP Management Domain/i) && ($#lines>2))
        #  {
        #  $line = shift(@lines);
        #  }
        
        if($line =~ /VTP Management Domain/i)
          {
          $line =~ s/VTP Management Domain:\s+//;
          $line =~ s/\'//g;
          $vtp_domain = $line;
          }
        $line = shift(@lines);
        }
   if(!(defined($loc))) { die "location nor defined\n";}
   if(!(defined($rem))) { die "irem location nor defined\n";}
   if(!(defined($ip_rem))) { die "ip rem nor defined\n";}
   if(!(defined($platform))) { die "platform not defined\n";}
   if(!(defined($cap))) { die "location nor defined\n";}
   if(!(defined($os_ver))) { die "$device os ver nor defined\n";}

   print  "$device",",$loc,$rdevice,$ip_rem,$rem,$platform,$cap,$image,$os_ver,$vtp_domain\n"; 
   print CDP "$device,$loc,$rdevice,$ip_rem,$rem,$platform,$cap,$image,$os_ver,$vtp_domain\n"; 
   # if found seek following
   }
#die;
return;
}

# --------------------------- extract_name -----------------------------
sub  extract_name
{
$line = shift;
if($line !~ /\:/) { die "line is => $line\n";}
($b,$b) = split(/\:\s/,$line);
$b =~ s/[^ -~]+//g; 
  ($rdevice) = split(/\./,$b);
return $rdevice;
}
# --------------------------- function get_pos ----------------------------
sub  get_pos     
{
my $line = shift;
my (@elements) = split("",$line);
my $pos1 =0;
for($i=1;$i<=($#elements);$i++)
   {
    if($elements[$i] eq 'S')
      {
       $pos1 = $i;
      }
    if($elements[$i] eq 'P')
      {
       $pos2 = $i;
      }
    if($elements[$i] eq 'D')
      {
       $pos3= $i;
       last;
      }
   }
return $pos1,$pos2,$pos3;
} 
# -------------------------------- norm_int --------------------------------------
sub norm_int
{

$int = shift;

# print "\nNORm INT int is =>$int\n\n";


$pre = substr($int,0,2);
($b,$in) = split(/^\D+/,$int);
$int = "$pre$in";
# print "PRE => $int\n";
#$int =~ s/[^ -~]+//g; 
return $int;
}
# -------------------------------- get_ios_info --------------------------------
sub get_ios_info
{
$line = shift;
(@elements) = split(/\s/,$line);
#print "IOS => @elements \n\n";
foreach $item (@elements)
  {
   #if(($item =~ /\)\,$/) && ($item =~ /^\(/))
   if($item =~ /^\(.*\)\,$/) 
     {
      $img = substr($item,0,($#item-1));
      $img =~ s/\(+//g; 
      #print "we have image $img\n";
      next;
     }
   if($item =~ /^\d+.*\,$/)
     {
      $ver = substr($item,0,$#item);     
      #print "we have ver $ver\n";
     }
  }
if(!(defined($img)))
  {
   print "LINE is $line \nItem is $item\n";
   print "elements are: @elements\n";
   die;
  }
  
return $img, $ver;
}
# --------------------------- pre_process_files ---------------------------
sub pre_process_file
{
@lines = @_;
@tmp = ();
foreach $line (@lines)
  {
  if($line =~ /END SH CDP/)
    {
    last;
    }
  push(@tmp,$line); 
  }  
return @tmp;
}
