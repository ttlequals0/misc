#!/usr/bin/perl -w   
# script will compare 2 lists of neighbor status at 4pm  and at 6:10pm          
#  files with devices status are located in output fiolder
#   nameing convention {device dns}.out after
#                      {device dns}.out.before before scan
# command oputput collected for all actively managed devices:
#         sh interface description 
#use Net::SSH::Perl;
#use Expect;

@file_list = `ls -1 /data/engineering/networking/02-09-swcheck/output/*out`;

# create temp file to test output
$file ="Interface_status_report.csv";
open(OUT, ">$file") || die "cant open $file file \n";
$file ="Interface_exception_report.csv";
open(EXC, ">$file") || die "cant open $file file \n";

%before_interfaces = ();
foreach $next_file (@file_list)
   {
    chomp $next_file;
    @lines_to_add = process_files("$next_file.before","$next_file",\%before_interfaces);
    print @lines_to_add,"\n";
   }
print %before_interfaces,"\n";


# --------------------- process_files -------------------------------
sub process_files
# process each before and after file
{
$before = shift;
$after = shift;
$curr_hash = shift;
# get all neighbors for a given protocol
# keep removing lines untill 1st protocol 
# device name is $after without .out
#($device) = split('/data/engineering/networking/neighbor/output/',$after);
$device = $after;
$device =~ s/^.*\///;
$device =~ s/\.out//;

open(IN,"$before") or die "cant open $before file \n";
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

# ------------------------------- cut out --------------------------
sub junk
{
(@before) = read_file("/data/engineering/networking/files/SH_N_Before.txt");
@after = read_file("/data/engineering/networking/files/SH_N_after.txt");
$items ="1";
while(@before)
{
(@items) = split(" ",pop (@before));
 if($items[0] =~ /ttnet/)
    { print "Device: @items\n" }
 else
    {
     if($items[1] =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/)
       { $order =1;
        }
         else
         {
           if($items[4] =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/)
             {$order =4;}
           else
             {$order =5;}
         }

        # seek after to make sure its there
        $found = seek_after($items[$order]);
        print "neighbor: $items[$order], $found","\n";
    }

}
return @new_lines;


} # end junk

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
            if(($_ =~ /ttnet/) || ($_ =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/)) {
             

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
