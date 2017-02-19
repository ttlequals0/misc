#!/usr/bin/perl -w
# update acs tables
#
# pmw 1/9/2012

use DBI;
#use Text::CSV;
use Text::CSV;
#$file ="Active_Circuits.csv";
# open mysql
## mysql user database name
$db ="network_inv";
## mysql database user name
$user = "user";
## mysql database password
$pass = "password";

$host="119.0.0.205";

$dbh = DBI->connect('dbi:mysql:network_inv:119.0.200.99',$user, $pass) || die "failed $DBI::errstr";
$db_h = DBI->connect('dbi:mysql:buildmgr:119.0.0.205',$user, $pass) || die "failed $DBI::errstr";

#1.  acs table ACS_Administration
# date form ./logs/T*Administration*.csv
@header =("Date","Time","User-Name","Group-Name","cmd","priv-lvl","service","NAS-Portname","task_id","NAS-IP-Address","reason");
#<>;

$file ="debug_acs.log";
open(OUT, ">$file") || die "cant open $file file \n";

# lets start with ptp
# shove data into array then update db
`cat ./logs/T*Administration* | egrep -v "^Date," >Administration.csv`;

$file ="Administration.csv";
open(IN, "$file") || die "cant open $file file \n";
@lines = <IN>;
close(IN);
$csv = Text::CSV->new();
foreach my $line (@lines)
  {
  #chomp $line;
  $status = $csv->parse($line);        # parse a CSV string into fields
#  print " status is $status \n";
  (@items) = $csv->fields();            # get the parsed fields
  # print @items;

  for($i=0;$i<=$#items;$i++)
     {
     #print "$i Col-> ",$elem[$i]," Val-> ",$items[$i],"\n";  
       print "$i,",$header[$i]," -> ",$items[$i],";";
     }
 process_acs(@items);
  
  print "\nNEXT RECORD\n";
  }
die;
$file ="internet_circuits.csv";
open(IN, "$file") || die "cant open $file file \n";
$line = <IN>;
chomp $line;
#(@cur_head) = split(/\,/,$line);
@lines = <IN>;
close(IN);
$csv = Text::CSV->new();
foreach $line (@lines)
  {
  #chomp $line;
  $status = $csv->parse($line);        # parse a CSV string into fields
  print " status is $status \n";
  (@items) = $csv->fields();            # get the parsed fields
  # print @items;
  for($i=58;$i<=73;$i++)
     {
     $items[$i]="";
     }
  for($i=0;$i<$#items;$i++)
     {
     if($i==55)
       {
       $items[64] = $items[$i];
       $items[$i]="";
       }
     if($i==56)
       {
       $items[71] = $items[$i];
       $items[$i]="";
       }
     if($i==57)
       {
       $items[72] = $items[$i];
       $items[$i]="";
       }

     if(($items[$i] ne "") && ($items[$i] !~ /^\s+$/))
       {
       #print "$i -> ",$cur_head[$i]," <-> ",$header[$i+1]," Val-> ",$items[$i],"\n";
       print "$i -> ",$cur_head[$i]," <-> ",$header[$i+1]," Val-> ",$items[$i],"\n";
       }
     process_tems(@items)
     }
  }



# ------------------- get_columns ----------------
sub get_columns
{
my $table = shift;
my $sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0;"); 
$sth->execute; 
my @cols = @{$sth->{NAME}}; # or NAME_lc if needed 
$sth->finish; 
$i=0;
foreach ( @cols ) { 
printf( "$i : %s\n", $_ ); 
$header[$i] = $_;
$i++;
}

return;
}
# ---------------------------- do_update_record ------------------------
sub do_update_record
{
$table = shift;

$set_str = shift;
$where = shift;

$sth = $dbh->prepare(qq{update `$table` SET $set_str \
        where $where });
# execute above statement
$sth->execute;

$sth->finish;
}
# --------------------------------- do_add_acs ------------------------
# add new record to interface
sub do_add_acs
{
#($dev,$ip,$ver,$model,$image,$serial) = (@_);
@values = @_;
#$sql = compose_sql(@values);
$sql =  "`Date` = '$values[0]',";
$sql .= "`Time` = '$values[1]',";
$sql .= "`User-Name` = '$values[2]',";
$sql .= "`Group-Name` = '$values[3]',";
$sql .= "`cmd` = '$values[4]',";
$sql .= "`priv-lvl` = '$values[5]',";
$sql .= "`service` = '$values[6]',";
$sql .= "`NAS-Portname` = '$values[7]',";
$sql .= "`task_id` = $values[8],";
$sql .= "`NAS-IP-Address` = '$values[9]',";
if(defined($values[10]))
  {
   $sql .= "`reason` = '$values[10]',";
  }
$sql .= "`Date_Created` = CURDATE()";
$sql =~ s/\,$//;

$sql =~ s/[^[:print:]]//g;

if($values[2] =~ /\:/)
  {
  print "WTF->$sql \n";
  <>;
  }

#$sth = $dbh->prepare(qq{insert into `TEMS_Spreadsheet` \
#            (0,$str)});
$sth = $dbh->prepare(qq{insert into `ACS_Administration` \
            set $sql});
# execute the select statement
$sth->execute;

    ### add record to track
       print OUT "ADD ACS_Administration: 0,$sql";
       print OUT "\n";


$sth->finish;

# testing
#print $sql,"\n";
#<>;

return;
}
# --------------------------------- process_acs ------------------------
# add new record to ACS_Administration table
sub process_acs
{
@values = @_;
my $date = $values[0];
my $time = $values[1];
my $task = $values[8];
my $nas  = $values[9];
(@elem) = split(/\//,$date);
$date = $elem[2];
$date .= "-";
$date .= $elem[0];
$date .= "-";
$date .= $elem[1];
$values[0] = $date;
    $where = " `Date` = '$date' and `Time` = '$time' and `task_id` = $task";
    $where .= " and `NAS-IP-Address` = '$nas'"; 
    print "**** looking for => $where \n";

     $found =  do_seek_where("ACS_Administration",$where);

# print "found is $found \n ...wait for enter ...\n";
#<>;
   if($found)
     {
      # step 1 get DEVICE_ID
       # need to construct set
       #print "ETF-> ",@last_row,"\n";
       #<>;
       $set = "task_id = $task";

         do_update_record("ACS_Administration",$set,$where);
     }
   else
     {

         do_add_acs(@values);

     }

return;
}
# --------------------------------- do_seek_where ------------------------

sub do_seek_where
{
$table = shift;
$where = shift;
 $found = 0;
my @row=();
@last_line = ();
$sth = $dbh->prepare(qq{select * from `$table` \
        where $where });
# execute the select statement
$sth->execute;
while (@row = $sth->fetchrow_array)
{
 if(defined($row[0]))
   {
   $found = $row[0];
   @last_line = @row;
   }
}
# end the reading of results
$sth->finish;

  if($found != 0) { 
   print "SEEK FOUND ROW: $found ",$last_line[3],",",$last_line[2],"\n";
   }
return $found;
}

# --------------------------------- dump_row --------------------
sub dump_row
{
@values =@_;



return;
}
# --------------------------------- compose_sql --------------------
sub compose_sql
{
$values = @_;
# for TEMS_spreadsheet table

  $sql = "";

  for($i=0;$i<$#values;$i++)
     {
     #print "$i Col-> ",$elem[$i]," Val-> ",$items[$i],"\n";
     $values[$i] =~ s/^\s+//;
     $values[$i] =~ s/\s+$//;
     $values[$i] =~ s/\'/''/g;
     if($values[$i] eq "") {next;}
     $sql .= "`";
     $sql .= $header[$i+1];
     $sql .= "` = '";
     $sql .= $values[$i];
     $sql .= "',";
     #print "$i -> ",$cur_head[$i]," <-> ",$header[$i+1]," Val-> ",$items[$i],"\n";
     }
$sql =~ s/,$//;


return $sql;
}





