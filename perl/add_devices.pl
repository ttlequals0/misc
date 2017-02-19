#!/usr/bin/perl
# update device data table
# hardware-report.csv is obtained from cwsi ( need to cron report on ciscomgr)


#Device Name,Updated At,System Description,Location,Contact,Serial Number,Vendor
#Type,HW Version,FW Version,RAM Size (MB),NVRAM Size (KB),NVRAM Used (KB),Backpla
#ne Description,Power Supply 1,Power Supply 2

require Text::CSV;
use DBI;
# use Net::Nslookup;
my $csv = Text::CSV->new;

$dest = 'localhost';
$dbh = DBI->connect('dbi:Oracle:host=localhost','user','en1gma31') || \  
 die "failed $DBI::errstr";

# open hardware-report and parse for device data


do_fix_data();

$file = "hardware-report_.csv";
if (! open (IN, "$file") ) { die "cant open file $file\n"; }
$model_series = "";

while(<IN>)
{
  if ($csv->parse($_)) {
        @elements = $csv->fields;
        
        }
   else
     { next;
     }
   # print @elements,"\n";
   # print $#elements,"\n";
   if($elements[0] =~ /^Cisco/)
      {
       ($b,$model_series) = split("Cisco",$elements[0]);
        print "Model Series ==> $model_series \n\n";
      } 
   if(($#elements < 10 ) || ($elements[0] =~ /Device Name/)) 
      {
       next;
       }  
   print "dev => $elements[0], type => $elements[6], contact => $elements[4]\n";
   $code_ver = do_extr_ver($elements[2]);
   print "serial => $elements[5]  code ver => $code_ver \n";
   
   # seek DEVICS based on name
   # if not found add new row
   # if found update
   do_process_device($elements[0],$elements[3],$elements[6],$elements[4],$elements[5],$code_ver,$model_series);   

}  # end while <IN>


# ------------------------------ do_extr_ver ----------------------------------
sub do_extr_ver
{
#extract IOS ver from string
$string = shift;
(@items) = split(",",$string);

foreach $item (@items)
{
 if ($item =~ /Version/)
    {
     ($string,$code_ver) = split(" ",$item);
     $item = $code_ver; 
     ($code_ver) = split("Copyright",$item); 
     return $code_ver;
     }

}
return "";
}
#------------------------------ do_fix_data ------------------------------------
sub do_fix_data
{
$file = "hardware-report.csv";
if (! open (IN, "$file") ) { die "cant open file $file\n"; }
@in_file = <IN>;
close(IN);
@all_char = "";
foreach $line (@in_file)
{
  (@temp) = split("",$line);
  foreach $char (@temp)
    {
     push(@all_char,$char);
    } 

}

# print @all_char;

#print "size of array is => $#all_char \n";



$curr = shift(@all_char);

$out_file ="";

while ($#all_char > 0)
{
 $curr = shift(@all_char);
 # print "curr => $curr \n";

if($curr =~ /"/)
  {
   # print "curr => $curr \n";
   # remove all line break charactes untill next "
   $out_file .= $curr;  
   $curr = shift(@all_char);
   if ($curr !~ /\n/)
      {
      $out_file .= $curr;
      } 
   while($curr !~ /"/)
        {
         $curr = shift(@all_char);                       
         if ($curr !~ /\n/)
            {
             $out_file .= $curr;  
 #print "FIELD curr => $curr \n";
                   
            }
                 
        }
   }
else
   {

$out_file .= $curr;  
   }
}
$file = "hardware-report_.csv";
if (! open (OUT, ">$file") ) { die "cant open file $file\n"; }
 print OUT $out_file;
close(OUT);
return;
}

# --------------------------------- do_seek_where ------------------------

sub do_seek_where
{
$table = shift;
$where = shift;
 $found = 0;
 
$sth = $dbh->prepare(qq{select * from "$table" \ 
        where $where });
# execute the select statement
$sth->execute;
while (@row = $sth->fetchrow_array)
{
   print "SEEK FOUND ROW:  @row\n";
 $found = $row[0];
 @last_line = @row;
}
# end the reading of results
$sth->finish;

return $found;
}
# ----------------------------------- do_update_record ------------------------
sub do_update_record
{
$table = shift;

$set_str = shift;
$where = shift;

$sth = $dbh->prepare(qq{update "$table" SET $set_str \ 
        where $where });
# execute above statement
$sth->execute;

$sth->finish;
}
# --------------------------------- do_add_dev ------------------------
# add new record to interface
sub do_add_dev
{
$device_name = shift;
$model = shift;
$location = shift;
$code_ver = shift;
$dev_type = shift;
$serial = shift;
$dev_ip = shift;
$model_series = shift; 



$sth = $dbh->prepare(qq{insert into "DEVICES" \ 
        values (0,'$device_name','$model','$location','$code_ver','','','$serial','','',\
        '$dev_ip','$model_series','','','') });
# execute the select statement
$sth->execute;

    ### add record to track
       print OUT "ADD DEVICE: 0,'$device_name','$model','$location','$code_ver','','',";
       print OUT "'$serial','','','$dev_ip','$model_series ','',''";
       print OUT "\n";
             
   

#while (@row = $sth->fetchrow_array)
#{
# print "ECHO: ";
#print "@row\n";
#}
# end the reading of results
$sth->finish;

return;
}
# --------------------------------- do_process_device ------------------------
sub do_process_device
{
# process device
$dev = shift;
$loc = shift;
$type = shift;
$contact = shift;
$serial = shift;
$code_ver = shift;
$model = shift;

# do not add any devices that contain ip address in name field
#
if($dev =~ /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/)
  {
   # ip address move to next
   return;
  }


$dev_ip = do_get_ip($dev);
  # seek DEVICES based on name

$where = '"Device_Name"';
$where .= " like '$dev%'";
#$where .= '%';
#$Where .= $dev;
#$where .= "%'"; 
#print "dev is => $dev \n";
#print "**** looking for => $where \n";
   $found =  do_seek_where("DEVICES",$where);
   if($found)
     {
      # update record
      # print "***** FOUND = > $found \n";
      print "$last_line[10] => $dev_ip \n";
      print "$last_line[1] => $dev \n";
      print "$last_line[4] => $code_ver \n";
      print "$last_line[2] => $type \n";
      print "$last_line[3] => $loc \n";
      print "$last_line[7] => $serial \n";
      print "$last_line[11] => $model \n";
 
      if(($last_line[2] !~ /$type/) || (length($last_line[2]) <1))
         {
    
         print "LENGTH of  last_line[2] is ";
         print length($last_line[2]);
         print "\n";
             if(length($type) >39)  { $type = substr($type,0,39);}
          $set = '"Model_Info" = ';
          $set .= "'$type'";
          do_update_record("DEVICES",$set,$where);
         }
       if(($last_line[3] !~ /$loc/) || (length($last_line[3]) <1))
         {
          $set = '"Location" = ';
          $set .= "'$loc'";
          do_update_record("DEVICES",$set,$where);
         }
       if(($last_line[4] !~ /$code_ver/) || (length($last_line[4]) <1))
         {
          $set = '"Code_Ver" = ';
          $set .= "'$code_ver'";
          do_update_record("DEVICES",$set,$where);
         }
       if(($last_line[7] !~ /$serial/) || (length($last_line[7]) <1))
         {
          $set = '"Serial_Number" = ';
          $set .= "'$serial'";
          do_update_record("DEVICES",$set,$where);
         }
       if(($last_line[10] !~ /$dev_ip/) || (length($last_line[10]) <1))
         {
          $set = '"Management_IP" = ';
          $set .= "'$dev_ip'";
          do_update_record("DEVICES",$set,$where);
         }
       if(($last_line[11] !~ /$model/) || (length($last_line[11]) <1))
         {
          $set = '"Model_Series" = ';
          $set .= "'$model'";
          do_update_record("DEVICES",$set,$where);
         }
      }
   else
     {
      
      # add new record
      do_add_dev($dev,$model,$location,$code_ver,$type,$serial,$dev_ip,$model); 

     }



return;
}
# ------------------------------------ do_get_ip --------------------------------
sub do_get_ip
{
$host = shift;

$dev_ip = "";


$str = `nslookup $host `  ;

@lines = split(/\n/,$str);
while(1)
{
 $line = pop(@lines); 
 if($line =~ /Address:/)
   {
    chomp $line;
    ($str,$dev_ip) = split(" ",$line);
    last;
   }
}


return $dev_ip;
}

#---------------------------------- all_trim ------------------------------------
sub all_trim
{
$str_to_trim = shift;
$str_to_trim =~ s/^\s+//;
$str_to_trim =~ s/\s+$//;
return $str_to_trim;
}

