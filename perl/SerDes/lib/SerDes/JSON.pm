# lib/SerDes.pm
package SerDes::JSON;

use Moose;
use namespace::autoclean;
use feature qw/switch state/;

extends 'SerDes';

our $VERSION = '1.01000';

has '_type_aliases' => ( is => 'ro', isa => 'ArrayRef[Str]', init_arg => undef,
					     default => sub{[qw/json/]} );
has '_default_ext'  => ( is => 'ro', isa => 'Str', init_arg => undef,
						 default => 'json');

sub _load_module
{
	my $self = shift;
	unless(eval{require JSON})
	{
		$self->error("JSON not installed");
		return ();
	}
	
	use JSON;
}

sub guess_type($$)
{
	my($self,$data) = @_;
	
	return $data =~ /^\s*{/;
}

sub serialize($$;$)
{
    my($self,$data,$filename) = @_;
   
    return () unless $self->_load_module;
    
	my $serial_data = JSON::to_json($data, {pretty => 1});
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
    eval{ $ret = JSON::decode_json($data) };
    if($@)
    {
        $self->error("$@ for: $input");
        return ();
    }
    
    return $ret;
}

1;
