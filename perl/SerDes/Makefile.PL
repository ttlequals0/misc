#!/usr/bin/env perl

use inc::Module::Install;

name     'SerDes';
all_from 'lib/SerDes.pm';
include  'Module::AutoInstall';

perl_version                         => '5.10002';
requires 'Moose'                     => '2.0604';
requires 'YAML'                      => '0.84';
requires 'XML::Simple'               => '2.20';
requires 'Storable'                  => '2.27';
requires 'Data::Dumper'              => '2.130_02';
requires 'Config::INI::Serializer'   => '0.001';
requires 'namespace::autoclean'      => '0.13';
requires 'Module::Pluggable::Object' => '3.9';
test_requires 'File::Compare'        => '1.1006';
test_requires 'Test::Most'           => '0.31';
test_requires 'File::Path'           => '2.08';

auto_install;
WriteAll;
