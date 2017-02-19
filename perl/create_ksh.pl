#!/usr/bin/perl -w
# compile a ksh script to poll devices for neighbors
use Net::SSH::Perl;
use Net::Telnet;


$file = "/data/engineering/networking/02-09-swcheck/dev_to_check.txt";
open( FILE, "$file" ) or die "Can't open $filename : $!";
@lines = <FILE>;
close(FILE);
$file = "/data/engineering/networking/02-09-swcheck/get-data.ksh";
open( FILE, " >$file" ) or die "Can't open $filename : $!";
print FILE "#!/bin/ksh\n";
print FILE "cd /data/engineering/networking/02-09-swcheck \n";
foreach $line (@lines)
  {
    chomp $line;
   ($dev_name,$ip) = split(/\s+/,$line);
   print FILE "./get_status.exp $ip ssh > output/$dev_name.out & \n";
  }
print FILE "wait\n";
print FILE "if [[ \$1 = \"before\" ]]; then\n";
print FILE "cd output\n";
print FILE "for foo in \$(ls \*out);do\n";
print FILE "if [[ -e \$foo ]];then\n";
print FILE " mv \${foo} \${foo}\.before\n";
print FILE "fi\n";
print FILE "done\n";
print FILE "fi\n";


close(FILE);
system("chmod +x get-data.ksh");

