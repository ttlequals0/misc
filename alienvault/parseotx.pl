#!/usr/bin/perl -w
use Sys::Syslog;

##Format of list:   IP, #, #, description
##Values we care about: 0 and 3 (zero-based)

unless (open INPUT, "/etc/ossim/server/reputation.data") {
  die "Cannot find input file: $!";
  }
unless (open OUTPUT, ">otx.csv") {
  die "Cannot open output file: $!";
  }

while (<INPUT>) {
  chomp;
  next if /.*#Scanning Host#/g;
  next if /.*#Spamming#/g;
  next if /.*#Scanning Host;Spamming#/g;
  next if /.*#Spamming;Scanning Host#/g;
  my @line = split(/#/);
  #print "@line\n";
  #exit;
  # skip blank lines
  next if /^(\s)*$/;
    print OUTPUT "$line[0]#$line[3]\n"; 
}
close (INPUT);
close (OUTPUT);
