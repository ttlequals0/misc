#!/usr/bin/perl -w
# process output from cisco devices, sh access-list | inc 10200
# extract number of hits on prot from output
# create 2 output files:
#     current.csv and errors.txt
#

use Net::SMTP;
@file_list = `ls -1 ./output/*out`;

# create temp file to test output
$file ="current.csv";
$old_date = get_file_date($file);
open(IN, "$file") || die "cant open $file file \n";
@lines = <IN>;
close(IN);
%dev_hits =();
%dev_list =();
foreach $line (@lines)
 {
  chomp $line;
  ($dev,$acl,$isp,$hits) = split(/\,/,$line);
  #print "$dev,$ip,";
  $dev_hits { "$dev,$acl,$isp" } = $hits;
  #print $dev_hits { $dev };
  #print "\n";
 }

system("cp current.csv old.csv");
open(OUT, ">$file") || die "cant open $file file \n";
$file = "acl_hits_report.csv";
open(REP, ">$file") || die "cant open $file file \n";
foreach $next_file (@file_list)
   {
    chomp $next_file;
    process_files("$next_file");
   }
foreach $key (sort keys %dev_list)
   {
    ($device,$acl,$isp) = split(/\,/,$key);
    $num = $dev_list { $key };
    print  "$device $isp ";
    print  $dev_list { "$device,$acl,$isp" };
    print  "\n";
    print OUT "$device,$acl,$isp,$num\n";
    print REP "$device,$acl,$isp,";
    if(defined($dev_hits { "$device,$acl,$isp" }))
      {
       print REP $dev_hits { "$device,$acl,$isp" };
      }
    print REP ",$num\n";
    #print REP $dev_hits { "$device,$acl" };
    
   }
close(OUT);
close(REP);
$new_date = get_file_date($file);
open(IN, "$file") || die "cant open $file file \n";
@lines = <IN>;
close(IN);
if(($old_date eq $new_date) || ($old_date eq ""))
  {
  die "Both dates are the same Old Date->$old_date New Date->$new_date\n";
  }

open(REP, ">$file") || die "cant open $file file \n";
print REP "Device,ACL,ISP,$old_date # of hits,$new_date # of hits,Comments\n";
foreach $line (@lines)
 {
 chomp $line;
 ($dev,$acl,$isp,$before_hits,$after_hits) = split(/\,/,$line);
 print REP "$dev,$acl,$isp,$before_hits,$after_hits,";
 if(($before_hits =~ /^\d+$/) && ($after_hits =~ /^\d+$/))  
   {
   if($before_hits == $after_hits)
     {
     #send email alerts to network security
  #   if(($dev =~ /\-ch-|\-uk-/) and ($isp =~ /backup.*shadow port/i))
  # 4/23/12 pmw changed from above to V
     if(($dev =~ /\-ch-|\-uk-/) and ($isp =~ /shadow port/i))
       {
       print REP "Backup";
       }
     else
       {
       print REP "Same";
       print "$dev,,$acl,$isp,$before_hits,$after_hits\n";
   #  check net flow vefore sending email
     $is_flow = get_flow($dev);
       if((!($is_flow)) && ($dev =~ /ttnet-ny-swedge-2/))
         {
          $is_flow = get_flow('ttnet-ny-swedge-1');
         }
       if((!($is_flow)))
         {  
       print "generating email\n";
       s_mail($dev,"$acl - $isp",$old_date,$new_date,$before_hits);   
         }
    # end add check netflow 5/16/2012
       }
     }
   print REP "\n";
   }
 }
#
# --------------------- process_files -------------------------------
sub process_files
# process each before and after file
{
$device = shift;
# get all neighbors for a given protocol
# keep removing lines untill 1st protocol
# device name is $after without .out
open(IN,"$device") or die "cant open $device file \n";
@lines = <IN>;
close(IN);
$device =~ s/^.*\///;
$device =~ s/\.out//;
$ip="";
$service ="";
 $line = "";
 @isps = ();
 # find device name - pattern xxx>term
while($#lines >0)
 {
 $line = shift(@lines);
 chomp $line;
 # print $line;
   # find acl hits
   if($line =~ /ssh.*(\d+\.)\d+/)
     {
      ($ip) = (split(/\s+/,$line))[4];
      print "found $ip \n";
      
     }
   if($line =~ /^\D.*up.*up.*[cid|id][\:|\s+]/i)
     {
       if($line =~ /[\:|\s+]CID\s+/i)
         {
          $line =~ s/CID.*$//i;
         }
      ($isp) = (split(/[iI][dD]\:/,$line))[0];
      $isp =~ s/\s+[id|cid]$//i;
      $isp =~ s/^.*\s+up\s+//;
      $isp =~ s/\,.*$//;
      $isp =~ s/[cC]onnection//;
      $isp =~ s/\s+$//;
      print "found ISP $isp \n";
      push(@isps,$isp);

     }
   if($line =~  /sh run interface/)
     {
     last;
     }
  }
while($#lines >0)
 {
 $line = shift(@lines);
 chomp $line;
   if($line =~ /access-group/i)
     {
      ($acl) = (split(/\s+/,$line))[3];
      
      print "found ACL $acl \n";

     }

   if($line =~ /10200.*\d+/)
     {
      ($num) = (split(/\(/,$line))[1];
      $num =~s/\s+.*$//;
      print "found $acl,$num \n";
      $isp = shift(@isps);
      $dev_list { "$device,$acl,$isp" } = $num;
      
     }
 }
      
return;
}
# ------------------------ process_cfg --------------
sub process_cfg
{
$device = shift;
open(IN,"$device") or die "cant open $device file \n";
@lines = <IN>;
close(IN);
$device =~ s/\/home\/user\/vip_rep\/configs\///;
$device =~ s/\.cfg//;
$ip="";
 # find device name - pattern xxx>term
while($#lines >0)
 {
 $line = shift(@lines);
 if($line =~ /inside\,outside.*tcp/)
    {
    ($b,$b,$b,$out_ip,$port,$in_ip) = split(/\s+/,$line);
    $fw_static { "$in_ip,$port" } = "$out_ip";
    # get application name based on port 
    $appl = get_app($port);
    #print OUT "$device,$out_ip,$in_ip,$port,$appl,";
    print OUT "$device,$out_ip,$port,$appl,";
    
    if(defined($gr_stat { "$in_ip" }))
      {
       # associate client based on owner name IP
       $gr_stat { "$in_ip" } =~ s/-new//;
       ($clinet,$css_ip) = split(/\,/,$gr_stat { "$in_ip" });
       #print  OUT $gr_stat { "$in_ip" };
       print OUT "$clinet,$in_ip,$css_ip";
       
       
      }
    else
      {
      print OUT ",NO CSS,$in_ip";
      # ASSOCIATE CLIENT BASED ON IP LOOKUP		
      }
    print OUT "\n";
    #<>;
    }
 }

return;
}
# ----------------------------------- get_app ------------
sub get_app
{
$port = shift;
$appl= "";

if($port <= 10202 && $port >=10200)
  {
  $appl= "XTRH";
  }
if($port == 10250)
  {
  $appl= "X-Study";
  }
if($port == 6115)
  {
  $appl= "X-risk";
  }
if($port <=10602 && $port >=10500)
  {
  $appl= "FIX";
  }



return $appl;
}


# -------------------------------- get_file_date --------------------------
sub get_file_date
{
$file = shift;
if(!(-e $file)) { die "file $file does not exists \n"; }

$date = `ls -l --time-style=+%Y%m%d%H%M $file`;
$date =~ s/(\S+\s+){5}//;
$date =~ s/\s+.*$//;
$date =~ s/\s+$//;
$b = join('/',substr($date,0,4),substr($date,4,2),substr($date,6,2));
$b .= " ";
$b .= substr($date,-4,2);
$b .= ":";
$b .= substr($date,-2);
$date =$b;

print $date,"\n";





return $date;
}

# --------------------s_mail------------------------------
sub s_mail
{
#
# Create the object without any arguments,
# i.e. localhost is the default SMTP server.
#
$dev = shift;
$ip = shift;
$old_date = shift;
$new_date = shift;
$hits = shift;
$rep=`cat acl_hits_report.csv`;
$smtp = Net::SMTP->new("119.0.0.206");

$smtp->mail($ENV{USER});
    $smtp->to('user\@domain');
    $smtp->to('user\@domain');
    $smtp->to('user\@domain');

    $smtp->data();
#   $smtp->datasend("From: me\@$ENV{USER}");
    $smtp->datasend("To: user\@domain\n");
    $smtp->datasend("Subject: ACL counter Alert, Internet router $dev $ip ");

    $smtp->datasend("\n");
    $smtp->datasend("ACL counter on Internet router $dev $ip not increasing.\n");
    $smtp->datasend("Hits on $old_date same as on $new_date ($hits)\n");
    $smtp->datasend("Vendor might not be properly advertising public addresses. \nPlease investigate\n");
    #$smtp->datasend("List :\n$rep");
    $smtp->dataend();

    $smtp->quit;

print "Mail Sent\n\n";
return 0;
}
# --------------------get_flow------------------------------
sub get_flow
{
my $device = shift;
my $flows;
my $test = `cat ip_flow.csv | grep $device`;
($undef,$hits) = split(/\,/,$test);

if($hits <=1)
  {
  $hits = 0;
  }

return $hits;
}
