# lib/SerDes.pm
package SerDes::Storable;

use Moose;
use namespace::autoclean;
use feature qw/switch state/;

extends 'SerDes';

our $VERSION = '1.01000';

has '_type_aliases' => ( is => 'ro', isa => 'ArrayRef[Str]', init_arg => undef,
					     default => sub{[qw/ps store storable/]} );
has '_default_ext'  => ( is => 'ro', isa => 'Str', init_arg => undef,
						 default => 'store');

sub _load_module
{
	my $self = shift;
	unless(eval{require Storable})
	{
		$self->error("Storable not installed");
		return ();
	}
	
	use Storable;
}

sub guess_type($$)
{
	my($self,$data) = @_;
	return 0;
}

sub serialize($$;$)
{
    my($self,$data,$filename) = @_;
   
    return () unless $self->_load_module;
   
    if($filename)
    {
        Storable::store($data, $filename);
		return 1;
    }
	else
	{
		return Storable::freeze($data);
	}
}

=head2 deserialize

=cut
sub deserialize($$)
{
    my($self,$input) = @_;
	
	return () unless $self->_load_module;
    
	my $data;
	if($input !~ m/\n/ and -e $input)
	{
		$data = Storable::retrieve($input);
	}
	else
	{
		$data = Storable::thaw($input);
	}
    
    return $data;
}

1;
