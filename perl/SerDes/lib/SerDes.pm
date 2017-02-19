# lib/SerDes.pm
package SerDes;

use Moose;
use Module::Pluggable::Object;
use namespace::autoclean;
use Class::Load;
use feature qw/switch state/;

our $VERSION = '1.02005';
=head1 SerDes

SerDes - Serializer/Deserializer for data structures

=cut

has 'error' => ( is => 'rw', isa => 'Str', init_arg => undef );
has '_types' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );


=head1 Methods

=cut

=head2 serialize

=cut
sub serialize($$$;$)
{
    my($self,$data,$type,$filename) = @_;
   
    my $serial_data = $self->_types->{$type}->serialize($data, $filename);
    return $serial_data;
}

=head2 deserialize

=cut
sub deserialize($$;$)
{
    my($self,$input,$type) = @_;
	
	unless($type)
	{
		$type = $self->_resolve_type_alias($input =~ m/\.(\w+)$/);
	}
	unless($type)
	{
		$type = $self->_guess_type($input);
	}
	unless($type)
	{
		$self->error("Could not determine type");
		return ();
	}

    my $ret;
    eval{ $ret = $self->_types->{$type}->deserialize($input) };
    if($@)
    {
        $self->error("$@ for: $input");
        return ();
    }
    
    return $ret;
}

=head1 Private Methods

=cut

=head2 _build__types

=cut
sub _build__types

{
	my $self = shift;
	my $base = __PACKAGE__;
	my $mp = Module::Pluggable::Object->new( search_path => [$base] );
	my @classes = $mp->plugins;
	my %types;
	
	foreach(@classes)
	{
		Class::Load::load_class($_);
		my($name) = $_ =~ m/^\Q${base}::\E(.+)/;
		next if( $name eq 'Dumper' );
		$types{$name} = $_->new;
	}
	return \%types;
}

=head2 _prep_data

=cut 
sub _prep_data($$)
{
    my($self,$input) = @_;
    
    #check if input is a file
    if($input !~ m/\n/ and -e $input)
    {
        #my $type = $self->_resolve_type_alias($input =~ m/\.(\w+)$/);
        
        open(FD, $input) or return ();
        my $data = do{local $/; <FD>};
        close FD;
        
        return $data;
    }
        
    $input = join('', @$input) if( ref $input eq 'ARRAY' );
    
	return $input;
}

=head2 _resolve_type_alias

=cut
sub _resolve_type_alias($$)
{
    my($self,$ext) = @_;
	
	keys %{$self->_types};
	while( my($name,$handle) = each %{$self->_types} )
	{
		foreach(@{$handle->_type_aliases})
		{
			return $name if( lc($ext) eq lc($_) );
		}
	}
}

sub _guess_type($)
{
	my($self,$input) = @_;
	while( my($name,$handle) = each %{$self->_types} )
	{
		return($input,$name) if $handle->guess_type($input);
	}
}

=head1 AUTHOR

name

=head1 LICENSE

Copyright (C) 2012  name

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

__PACKAGE__->meta->make_immutable;

1;
