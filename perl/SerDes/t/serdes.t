# t/SerDes/SerDes.t
#
# INI files do not rebuild references when deserialzed.  Need to tweak des and ser tests.
#

use strict;
use warnings;
use File::Compare;
use File::Path;
use Test::Most tests => 15;

$| = 1;

my $wd = 't/';
my $sd;
local $/;

#instantiation
BEGIN{ use_ok( 'SerDes' ) };
lives_ok { $sd = SerDes->new } 'Instantiation';

#_resolve_type_alias
is( $sd->_resolve_type_alias('yml'), 'YAML',
    '_resolve_type_alias yml' );
#is( $sd->_resolve_type_alias('PS'), 'Storable',
#    '_resolve_type_alias ps' );

#_guess_type
my $mfile = "$wd/data";
open(YML, "$mfile.yml") or die $!;
my $yml_text = <YML>;
close YML;
open(XML, "$mfile.xml") or die $!;
my $xml_text = <XML>;
close XML;
open(JSON, "$mfile.json") or die $!;
my $json_text = <JSON>;
close JSON;
open(INI, "$mfile.ini") or die $!;
my $ini_text = <INI>;
close INI;
ok( $sd->_types->{'YAML'}->guess_type($yml_text), 'guess_type yaml' );
ok( $sd->_types->{'XML'}->guess_type($xml_text), 'guess_type xml' );
ok( $sd->_types->{'JSON'}->guess_type($json_text), 'guess_type json' );
ok( $sd->_types->{'INI'}->guess_type($ini_text), 'guess_type ini' );

#_prep_data
open(YML, "$mfile.yml") or die $!;
my @yml_lines = do{local $/ = "\n"; <YML>};

#deserialize
my $master = { array1 =>
                 [ qw/a b c/, 1, 2, 3, { three => 3, four => 4} ],
               hash1 =>
                 { one => 'ONE', two => 2, array2 => [4, 5, 6] }
             };
$master->{arrayref1} = $master->{hash1}->{array2};
$master->{hashref1}  = $master->{array1}->[6];
# is_deeply( $sd->deserialize("$mfile.dump"), $master, 'deserialize dumper' );
is_deeply( $sd->deserialize("$mfile.yml"), $master, 'deserialize yaml' );
is_deeply( $sd->deserialize("$mfile.xml"), $master, 'deserialize xml' );
is_deeply( $sd->deserialize("$mfile.json"), $master, 'deserialize json' );
#is_deeply( $sd->deserialize("$mfile.ini"), $master, 'deserialize ini' );
lc($^O) eq 'mswin32'
	? is_deeply( $sd->deserialize("$mfile.win32.store"), $master, 'deserialize storable' )
	: is_deeply( $sd->deserialize("$mfile.linux.store"), $master, 'deserialize storable' );

#serialize
mkdir "$wd/test";
my $tfile = "$wd/test/test";
is( $sd->serialize($master, 'YAML'), $yml_text, 'serialize to memory' );

$sd->serialize($master, 'YAML', "$tfile.yml");
dos2unix("$tfile.yml");
ok(! compare("$mfile.yml", "$tfile.yml"), 'serialize yaml to file' );

$sd->serialize($master, 'XML', "$tfile.xml");
dos2unix("$tfile.xml");
ok(! compare("$mfile.xml", "$tfile.xml"), 'serialize xml to file' );

$sd->serialize($master, 'JSON', "$tfile.json");
dos2unix("$tfile.json");
ok(! compare("$mfile.json", "$tfile.json"), 'serialize json to file' );

#$sd->serialize($master, 'INI', "$tfile.ini");
# dos2unix("$tfile.ini");
# ok(! compare("$mfile.ini", "$tfile.ini"), 'serialize ini to file' );

$sd->serialize($master, 'Storable', "$tfile.store");
#lc($^O) eq 'mswin32'
#   ? ok(! compare("$mfile.win32.store", "$tfile.store"), 'serialize storable to file' )
#	: ok(! compare("$mfile.linux.store", "$tfile.store"), 'serialize storable to file' );


sub dos2unix
{
	my $file = shift;
	
	open(FILE, "<$file")
		or die $!;
	my $text = <FILE>;
	close FILE;
	
	$text =~ s/\r\n/\n/g;
	
	open(FILE, ">$file")
		or die $!;
	binmode FILE;
	print FILE $text;
	close FILE;
}

END
{
	rmtree "$wd/test";
}
