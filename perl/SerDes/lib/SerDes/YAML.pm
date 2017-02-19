# lib/SerDes.pm
package SerDes::YAML;

use Moose;
use namespace::autoclean;
use feature qw/switch state/;

extends 'SerDes';

our $VERSION = '1.01001';

has '_type_aliases' => ( is => 'ro', isa => 'ArrayRef[Str]', init_arg => undef,
					     default => sub{[qw/yaml yml/]} );
has '_default_ext'  => ( is => 'ro', isa => 'Str', init_arg => undef,
						 default => 'yml');

sub _load_module
{
	my $self = shift;
	unless(eval{require YAML})
	{
		$self->error("YAML not installed");
		return ();
	}
	
	use YAML;
}

sub guess_type($$)
{
	my($self,$data) = @_;
	
	return $data =~ /^\s*---/;
}

sub serialize($$;$)
{
    my($self,$data,$filename) = @_;
   
    return () unless $self->_load_module;
   
    my $serial_data = YAML::Dump($data);
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
	
    my $ret;
    eval{ $ret = YAML::Load($data) };
    if($@)
    {
        $self->error("$@ for: $input");
        return ();
    }
    
    return $ret;
}

1;
