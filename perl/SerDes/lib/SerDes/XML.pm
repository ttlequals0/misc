# lib/SerDes.pm
package SerDes::XML;

use Moose;
use namespace::autoclean;
use feature qw/switch state/;

extends 'SerDes';

our $VERSION = '1.01001';

has '_type_aliases' => ( is => 'ro', isa => 'ArrayRef[Str]', init_arg => undef,
					     default => sub{[qw/xml/]} );
has '_default_ext'  => ( is => 'ro', isa => 'Str', init_arg => undef,
						 default => 'xml');

sub _load_module
{
	my $self = shift;
	unless(eval{require XML::Simple})
	{
		$self->error("XML::Simple not installed");
		return ();
	}
	
	use XML::Simple;
}

sub guess_type($$)
{
	my($self,$data) = @_;
	
	return $data =~ /^\s*<\?xml version=\'\d*/;
}

sub serialize($$;$)
{
    my($self,$data,$filename) = @_;
    my $type;
	
    return () unless $self->_load_module;
	
	my $x = XML::Simple->new(XmlDecl => 1);
    my $serial_data = $x->XMLout($data);
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
    
    my $x = XML::Simple->new;
	my $ret;
    eval{ $ret = $x->XMLin($data) };
    if($@)
    {
        $self->error("$@ for: $input");
        return ();
    }
    
    return $ret;
}

1;
