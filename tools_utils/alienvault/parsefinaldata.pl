#!/usr/bin/perl -w
use strict;

if (-s "./matches") {`rm ./matches`;}

unless (open INPUT1, "threat_ips.txt") {
  die "Cannot find input file: $!";
  }
unless (open OUTPUT, ">matches.txt") {
  die "Cannot open output file: $!";
  }

my $size;
my $binary = 0;
my $toggle = 0;

my $threat_ip_lines = `cat ./threat_ips.txt | wc -l`;
chomp $threat_ip_lines;
my $cntr_line = 0;

print OUTPUT "#############################################################################################################################################################################################\n";
print OUTPUT "# Threat Intel Report using OTX and malwaredomainlist.com/mdlcsv.php data\n";
print OUTPUT "# Formatted for syslog'ing to AlienVault\n";
print OUTPUT "# Flow data headers are: Date  FlowStart  Duration  Proto(6=TCP/17=UDP)  SrcIP:Port  FlowDirection  DstIP:Port  Flags  Tos   NumberPackets  NumberBytes  pps  bps  Bpp  Flows\n";
print OUTPUT "# NOTE: pps = packets per second, bps = bits per second, Bpp = bytes per package\n";
print OUTPUT "#############################################################################################################################################################################################\n\n\n";

while (<INPUT1>) 
 {
   if ($cntr_line == 0) {print "\n  Processing line 1 of $threat_ip_lines - 0\% done\n"};
   if ($cntr_line > 1 && $cntr_line % 1000 == 0)
     { 
       my $percent = int(($cntr_line / $threat_ip_lines) * 100);
       print "  Processing line $cntr_line of $threat_ip_lines - $percent\% done\n"
     };
   $cntr_line +=1;
  
   chomp $_;
   my @line = split(/#/);
   $size = @line;
   #print "size is: $size\n";
   #exit;
   if ($size == 3)
    {
      open (INPUT2, "./flows_sample");
       {
         while (<INPUT2>)
          {
            chomp $_;
              #print "line[1] is: $line[1]\n";
              #print "dollar_ is: $_\n\n"; 
              my $temp1 = $line[1];
              my $temp2 = ":";
              my $temp3 = $temp1 . $temp2;
              my $ result = index($_,$temp3);
              #print "result is: $result\n";
            if ($result > 1 )
             {
              $binary = 1;
              #print "match\n";
              #print "result is: $result\n";
              #print "temp3 is: $temp3\n";
              #print "line[1] is: $line[1]\n";
              #print "line is: @line\n";
              #print "dollar_ is: $_\n\n"; 
              
              s/\s+/ /g;
              s/ / , /g;
              #####
              if ($binary == 1 && $toggle == 0)
               {
                 # 2014-12-15 , 09:32:10.805 , 15.046 , 6 , 61.147.107.70:443 , -> , 192.168.100.128:56440 , .AP.SF , 0 , 33 , 15411 , 2 , 8194 , 467 , 3
                 #print "dollar_underscore is: $_\n";
                 my $temp = $_;
                 s/ //g;
                 # 2014-12-15,09:32:10.805,15.046,6,61.147.107.70:443,->,192.168.100.128:56440,.AP.SF,0,33,15411,2,8194,467,3
                 #print "dollar_underscore is: $_\n";
                 my $internal_ip;
                 my @array1 = split (/,/);
                    #print "echo00\n";
                    #print "array1[4] is: $array1[4]\n";
                    #print "array1[6] is: $array1[6]\n";
                 if ($array1[4] =~ /^192.168./)
                  {
                    #print "echo01\n";
                    $_ = $array1[4];
                    my @array2 = split(/:/);
                    $internal_ip = $array2[0];
                  }
                 elsif ($array1[6] =~ /^192.168./)
                  {
                    #print "echo02\n";
                    $_ = $array1[6];
                    my @array2 = split(/:/);
                    $internal_ip = $array2[0];
                  }

                 #print "HERE $internal_ip\n";
                 $toggle = 1;
                 $_ = $temp;
                 if ($toggle == 1) 
                   { 
                     #my $name = `nslookup $internal_ip|grep in-addr.arpa|sed 's/.*\.in-addr\.arpa	name = //g'|sed 's/\.local\./\.local/g'`;
                     my $name = `nslookup $internal_ip|grep in-addr.arpa|sed 's/.*\.in-addr\.arpa.*	name = //g'|sed 's/\.local\./\.local/g'`;
                     print OUTPUT "NSLOOKUP: $internal_ip = $name#############################################################################\n";
                     #print OUTPUT "yep\n"; 
                   }
               }
              ######
              print OUTPUT "threat_intel_malwaredomains \, $line[0] \, $line[1] \, $line[2] \, $_\n";
             }
          }  
       }
       close(INPUT2);

    }
   elsif ($size == 2)
    {
      open (INPUT2, "./flows_sample");
       {
         while (<INPUT2>)
          {
            chomp $_;
              #print "line[0] is: $line[0]\n";
              #print "dollar_ is: $_\n\n"; 
              my $temp1 = $line[0];
              my $temp2 = ":";
              my $temp3 = $temp1 . $temp2;
              my $ result = index($_,$temp3);
              #print "result is: $result\n";
            if ($result > 1 )
             {
              $binary = 1;
              #print "match\n";
              #print "result is: $result\n";
              #print "temp3 is: $temp3\n";
              #print "line[0] is: $line[0]\n";
              #print "line is: @line\n";
              #print "dollar_ is: $_\n\n";

              s/\s+/ /g;
              s/ / , /g;
              #####
              if ($binary == 1 && $toggle == 0)
               {
                 # 2014-12-15 , 09:32:10.805 , 15.046 , 6 , 61.147.107.70:443 , -> , 192.168.100.128:56440 , .AP.SF , 0 , 33 , 15411 , 2 , 8194 , 467 , 3
                 #print "dollar_underscore is: $_\n";
                 my $temp = $_;
                 s/ //g;
                 # 2014-12-15,09:32:10.805,15.046,6,61.147.107.70:443,->,192.168.100.128:56440,.AP.SF,0,33,15411,2,8194,467,3
                 #print "dollar_underscore is: $_\n";
                 my $internal_ip;
                 my @array1 = split (/,/);
                    #print "echo00\n";
                    #print "array1[4] is: $array1[4]\n";
                    #print "array1[6] is: $array1[6]\n";
                 if ($array1[4] =~ /^192.168./)
                  {
                    #print "echo01\n";
                    $_ = $array1[4];
                    my @array2 = split(/:/);
                    $internal_ip = $array2[0];
                  }
                 elsif ($array1[6] =~ /^192.168./)
                  {
                    #print "echo02\n";
                    $_ = $array1[6];
                    my @array2 = split(/:/);
                    $internal_ip = $array2[0];
                  }

                 #print "HERE $internal_ip\n";
                 $toggle = 1;
                 $_ = $temp;
                 if ($toggle == 1)
                   {
                     my $name = `nslookup $internal_ip|grep in-addr.arpa|sed 's/.*\.in-addr\.arpa//g'|sed 's/.*name = //g'|sed 's/\.local\./\.local/g'`;
                     print OUTPUT "NSLOOKUP: $internal_ip = $name#############################################################################\n";
                     #print OUTPUT "yep\n"; 
                   }
               }
              ######
              print OUTPUT "threat_intel_otx \, $line[0] \, $line[1] \, $_\n";
             }
          }
       }
       close(INPUT2);
    } 

if ((eof INPUT2) && ($binary == 1)){print OUTPUT "\n";}
$binary = 0;
$toggle = 0;
 } #end of while loop on INPUT1


close(INPUT1);
close(OUTPUT);  
