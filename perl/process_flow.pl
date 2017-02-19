#!/usr/bin/perl -w
#
# 5/16/2012 pmw
# process ./output/*.flow files
# look for hits on port 10200  (x27db)


@file_list = `ls -1 ./output/*flow`;

# create temp file to test output
$file ="ip_flow.csv";
open(OUT, ">$file") || die "cant open $file file \n";
foreach $line (@file_list)
 {
  chomp $line;
  $test = `cat $line | grep 27D8 | wc -l`;
  chomp $test;
  $line =~ s/^.*\///;
  $line =~ s/\..*$//;
  print OUT "$line,$test\n";
  print  "$line,$test\n";
 }
close(OUT);
