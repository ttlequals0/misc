# lib/SerDes.pm
package SerDes::INI;

use Moose;
use namespace::autoclean;
use feature qw/switch state/;

extends 'SerDes';

our $VERSION = '1.01000';

has '_type_aliases' => ( is => 'ro', isa => 'ArrayRef[Str]', init_arg => undef,
					     default => sub{[qw/ini/]} );
has '_default_ext'  => ( is => 'ro', isa => 'Str', init_arg => undef,
						 default => 'ini');

sub _load_module
{
	my $self = shift;
	unless(eval{require Config::INI::Serializer})
	{
		$self->error("Config::INI::Serializer not installed");
		return ();
	}
	
	use Config::INI::Serializer;
}

sub guess_type($$)
{
	my($self,$data) = @_;
	
	return $data =~ /^\s*\[.+\]/;
}

sub serialize($$;$)
{
    my($self,$data,$filename) = @_;
   
    return () unless $self->_load_module;
	my $ini = Config::INI::Serializer->new;
   
    my $serial_data = $ini->serialize($data);
    if($filename)
    {
        unless( open FD, ">$filename" )
		{
			$self->error("$!");
			return ();
		}
        print FD $serial_data;
        close FD;
		return 1;
    }
    
    return $serial_data;
}

=head2 deserialize

=cut
sub deserialize($$)
{
    my($self,$input) = @_;
	
	return () unless $self->_load_module;
		
	my $data = $self->_prep_data($input);
    return () unless( defined $data );
	
	my $ini = Config::INI::Serializer->new;
    my $ret;
    eval{ $ret = $ini->deserialize($data) };
    if($@)
    {
        $self->error("$@ for: $input");
        return ();
    }
    
    return $ret;
}

1;
