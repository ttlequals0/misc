
#!/usr/bin/perl -w
# parse output to verify interface status before and after changes
# 
#
# 2/20/9
# archive previous file if exists


if($#ARGV < 0)
  {
  $do_process = 1;
  }
else
  {
  $do_process = $ARGV[0];
  }
#print localtime->[2];


$file='status_report.csv';

if( -e $file)
  {
  $date_string = ntime(ctime((stat($file)->mtime)));
  print "file $file updated on $date_string\n";
  system("sort $file > archives/status_report.$date_string");
  }

@files = `ls -1 output/*.out`;

open(OUT,">$file") or die "Can't open $file : $!";

foreach $line (@files)
  {
  chomp $line;
  process_files($line);
  }
close(OUT);
# grep first newest archive file and compare

if(!($do_process))
  {
  die "its too late for comp report to be genterated\n";

  exit;
   }


$file='status_report.csv';

open(IN,"$file") or die "Can't open $file : $!";

if( -e $file)
  {
  $date_string = ntime(ctime((stat($file)->mtime)));
  print "file $file updated on $date_string\n";
  system("sort $file > archives/multicast_routes.$date_string");
  }
$file_to_compare = get_compare();
$from_date = (split(/\./,$file_to_compare))[1];

@new = <IN>;
close(IN);

# temprary change 2/16/9
# $file_to_compare = "multicast_routes.20090213";


open(IN,"archives/$file_to_compare") or die "Can't open $file_to_compare : $!";

@base = <IN>;
close(IN);
$file = "discrepance_report.csv";
open(OUT,">$file") or die "Can't open $file : $!";
chomp $from_date;
$from_date =~ s/(^\d{4})(..)(..)$/$1\/$2\/$3/;
$date_string =~ s/(^....)(..)(..)/$1\/$2\/$3/;
print OUT "Source,Group,Router,In,Out,$from_date,$date_string\n";
# create hash
%new_lines = ();
%out_rep = ();
foreach $line (@new)
  {
  $new_lines { "$line" } = $line;
  }
foreach $line (@base)
  {
   #chomp $line;
   #$test = find_line($line,@new);
   if(defined($new_lines { "$line" }))
     {
      $test = $new_lines { "$line" };
     }
   else
     {
     $test ="";
     }
   if($line ne $test)
     {
      chomp $line;
      print "^^$line$test\n";
      #print OUT "$line,Present,Missing\n";
      $out_rep { "$line,Present,Missing" } = "$line,Present,Missing";

     }
 }
foreach $line (@base)
  {
  $new_lines { "$line" } = $line;
  }

foreach $line (@new)
  {
   #chomp $line;
   #$test = find_line($line,@new);
   if(defined($new_lines { "$line" }))
     {
      $test = $new_lines { "$line" };
     }
   else
     {
     $test ="";
     }
   if($line ne $test)
     {
      chomp $line;
      print "<>$line->$test\n";
      #print OUT "$line,Present,Missing\n";
      $out_rep { "$line,,New" } = "$line,,New";
     }
  }

foreach $key (sort keys %out_rep)
  {
   print OUT "$key\n";
  }

close(OUT);

# --------------------- process_files -------------------------------
sub process_files
# process each before and after file
{
$in_file = shift;
chomp $in_file;
# get all neighbors for a given protocol
# keep removing lines untill 1st protocol
# device name is $after without .out
#($device) = split('/data/engineering/networking/neighbor/output/',$after);
$device = $in_file;
$device =~ s/(^.*\/)(ttnet.*)\.out$/$2/;

open(IN,"$in_file") or die "cant open $in_file file \n";
@before_lines = <IN>;
close(IN);
while($#before_lines >1)
   {
    $current_line = shift @before_lines;
    chomp $current_line;
    if($current_line =~ /Status/) {last;}
   }
while($#before_lines >1)
   {
    $current_line = shift @before_lines;
    chomp $current_line;
    if($current_line !~ /(up|down|reset)/) {next;}
    if($current_line =~ />exit/) {last;}
   ($int,$status) = split(" ",$current_line);
   if($status =~ "admin")
     {
     $status = "admin down";
     }
   $description = get_desc($current_line);
   # print "$device,$int,$description,$status \n";
   $curr_hash->{ "$device,$int" } = "$description,$status" ;
   }
# scan after file and update output hash
open(IN,"$after") or die "cant open $after file \n";
@before_lines = <IN>;
close(IN);
while($#before_lines >1)
   {
    $current_line = shift @before_lines;
    chomp $current_line;
    if($current_line =~ /Status/) {last;}
   }
%tmp =();
while($#before_lines >1)
   {
    $current_line = shift @before_lines;
    chomp $current_line;
    if($current_line =~ />exit/) {last;}
   ($int,$status) = split(" ",$current_line);
   $status =~ s/admin/admin down/;
   $description = get_desc($current_line);
   # $description = substr($current_line,50,($#current_line-50));
   # print "After $device,$int,$status \n";
   $tmp{ "$device,$int" } = "$description,$status" ;
  }


  # update current_scan
#  while ( my ($key, $value) = each(%tmp) ) {
       print "Device is => $device \n";
   foreach $key (mysort (keys(%tmp)))
   #foreach $key (keys(%tmp))
     {
     $value = $tmp{ $key };
     if(defined($curr_hash->{$key}))
       {
       if($value ne $curr_hash->{ $key})
         {
          #compare status if different add record
          ($_,$bef_status) = split(",",$curr_hash->{ $key});
          ($_,$aft_status) = split(",",$value);
          if($bef_status ne $aft_status)
            {
            print EXC "$key,$curr_hash->{ $key},$value,Status Change\n";
            }
          else
            {
            print EXC "$key,$curr_hash->{ $key},$value,Descr. Change\n";
            }
          # different status or description
         }
       else
         {
         print OUT "$key,$value\n";
         }
       }
     else
       {
       print EXC "$key,,,$value,New Interface\n";
       # neighbor missing
       }
    }  # end while
 while ( my ($key, $value) = each(%curr_hash) ) {
     if(defined($tmp->{$key}))
       {
       if($value ne $tmp->{ $key})
         {
          print EXC "$key,$value *INT*\n";
          # different interface
         }
       else
         {
         # print OUT "$key,$value\n";
         }
       }
     else
       {
       print EXC "$key,$value,Neighbor Not Present\n";
       # neighbor missing
       }
    }  # end while

return;
}
# ------------------------------- seek_after -------------------------

sub seek_after
  {
   $seeking = shift;
   foreach $item (@after)
     {
      if ($item = $seeking)
         {
          return $item;
          }
      }
   return "";
}

# -----------------------  read_file ----------------------------------
sub read_file
    {
        my( $filename ) = shift;
        my @lines;

# keep track of previous line

        open( FILE, "< $filename" ) or die "Can't open $filename : $!";

        while( <FILE> ) {

            s/#.*//;            # ignore comments by erasing them
            next if /^(\s)*$/;  # skip blank lines
            # get device name then all neighbors
            # device name .ttnet
            # hash device name + all neighbors lines
            if(($_ =~ /ttnet/) || ($_ =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b
/)) {


            chomp;              # remove trailing newline characters

            unshift @lines, $_;    # push the data line onto the array
                 # print "next",$_,"\n";
             }
        }

        close FILE;

        return @lines;  # reference
    }
# ----------------------------- is_ip ---------------------------------
sub is_ip
{
$to_test = shift;
if($to_test =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/)
  {
   return 1;
  }
return 0;
}

# ----------------------- process-ospf -----------------------------
sub process_prot
{
$prot = shift;
$local_hash = shift;
$device = shift;
@before_lines = @_;
$b = "";
shift @before_lines;
#print @before_lines;
#   die;
#print "protocol is => $prot\n";
#die;
@new_lines = ();
while($#before_lines >1)
   {
   $c_line = shift @before_lines;
    # print "c line => $c_line \n";
   if($c_line =~ />sh ip/) { last;}
   if(is_ip($c_line))
     {
      chomp $c_line;
      # new neighbor lin
      if($prot eq "ospf")
        {
         if($c_line =~ / -/)
           {
           ($b,$b,$b,$b,$b,$neighbor,$interface) = split(" ",$c_line);
           }
         else
           {
           ($b,$b,$b,$b,$neighbor,$interface) = split(" ",$c_line);
           }
        }
      if($prot eq "eigrp")
        {
        ($b,$neighbor,$interface) = split(" ",$c_line);
        }
      if($prot eq "bgp")
       {
        $interface ="";
        ($neighbor) = split(" ",$c_line);
       }
      push(@new_lines,"$device,$prot,$interface,$neighbor");
      $local_hash->{ "$device,$prot,$neighbor" } = $interface;
      # print "device=>$device,prot=>$prot,int=>$interface,nei=>$neighbor \n";
     }
   } # end while
#print %local_hash;
return @new_lines;
}
# ------------------------- get_desc -----------------------------------
sub get_desc
{
$string = shift;
chomp $string;
$string =~ s/(up|down|admin|reset)//g;
$string =~ s/^\s+//g;
(@items) = split(" ",$string);
shift(@items);
$string ="";
#while ($#items >=0) {
#   if($items[0] =~ /(up|down|admin)/)
#     {
#     shift(@items);
#     }
#   else
#     {
#      last;
#     }
#  } # end while
#$string ="";
#foreach $item (@items)
#  {
#  $string .= $item;
#  $string .= " ";
#  }
 # print "devince is +>  $string \n";
    if($#items >=0)
      {
       foreach $item (@items)
        {
        $string .= $item;
        $string .= " ";
        }

       $string =~ s/,/;/g;
      }
    else
      {
      $string = "";
      }
return $string;
}

# ----------------------------- mysort --------------------------------
sub mysort
{
@tosort = @_;
%temp_info = ();
print @tosort;
print "\n-------------\n";
# print %tmp;
# die;
foreach $item (@tosort)
  {
   ($dev,$int) = split(",",$item);
   $key = convert_int($int);
   $temp_info { $key } = $item;
  }
 @tosort =();
 foreach $key (sort keys %temp_info)
    {
     push(@tosort,$temp_info { $key });
    }
print "sorted array is: @tosort\n";
return @tosort;
}
# ------------------------------ convert_int ----------------------
sub convert_int
{
$int = shift;
if ($int !~ /\//)
   {
   return $int;
   }
$pre = substr($int,0,2);
 $int =~ s/^\D\D//;
 $int =~ s/\s+//;
@atoms = split(/\//,$int);
#die;
$int=$pre;
foreach $item (@atoms)
  {
   if(length($item) < 2)
     {
     $int .="0$item\/";
     }
   else
     {
     $int .="$item\/";
     }
  }
$int =~ s/\/$//;

print " Int is $int - atoms -- @atoms \n";

return $int;
}
# ---------------------------- norm_int ------------------------------------
sub norm_int
{
$port = shift;

(@items) = split(//,$port);

if($#items < 2)
  {
   # print DB "norm_int()\nline => $line";
   print "norm_int()\nline => $line";
   die "ifile -> $file port is $port\n";
  }
$port = shift @items;
$port .= shift @items;
foreach $item (@items)
 {
  if($item =~/\d|\/|\.|\:/)
    {
    $port .= $item;
    }
 }
return $port;
}

# ---------------------------

sub month2num
{
$month = shift;


%mon2num = qw(
  jan 1  feb 2  mar 3  apr 4  may 5  jun 6
  jul 7  aug 8  sep 9  oct 10 nov 11 dec 12
);

return $mon2num{ lc substr($month, 0, 3) };

}
# --------------------------- ntime ------------------------------------
sub ntime
{
$string_ = shift;

(@elements) = split(/\s+/,$string_);

$month = month2num($elements[1]);
if($month < 10)
  {
   $month = "0$month";
  }
if($elements[2] < 10)
  {
   $elements[2] = "0$elements[2]";
  }

return  "$elements[4]$month$elements[2]";
}
# --------------------------- get_compare ------------------------------------
sub get_compare
{
(@list) = `ls -1 archives | sort -r`;
$today = `date +%Y%m%d`;
foreach $item (@list)
 {
 if($item !~ /($today)/)
   {
   return $item;
   }
 }



return "";
}
# --------------------------- find_line ------------------------------------
sub find_line
{
$to_find = shift;
@array_ = @_;

foreach $item_ (@array_)
  {
   if($to_find eq $item_)
     {
    # print "$item_$item_ : $to_find";
      return $item_;
     }
  }
print "$to_find oh well\n";
return "";
}













