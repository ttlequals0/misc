#!/usr/bin/perl
# procedure reads omping.data
#  updates  table omping_latency
#
# 4/22/2015 pmw
# input: 7t_omping.data
# omping_latency table 119.0.0.205 network_inv
#


use File::stat;
use Time::localtime;

use DBI;
# use Net::Nslookup;

$dest = 'localhost';
# open oracle db

# open mysql
## mysql user database name
$db ="network_inv";
## mysql database user name
$user = "user";
## mysql database password
$pass = "password";
## user hostname : This should be "localhost" but it can be diffrent too
$host="119.0.0.205";

$dbh = DBI->connect('dbi:mysql:network_inv:119.0.0.205',$user, $pass) || die "failed $DBI::errstr";

$start_time = elapsed_time(0);

$file = "omping.data";
if (! open (IN, "$file") ) { die "cant open file $file\n"; }
@lines = <IN>;
close(IN);

$poll_date = get_poll_date($file);

foreach $line (@lines)
{
   chomp $line;
#print "$line \n";
   #($dev_name,4int,$descr,$status,$speed,$duplex) = split(/\,/,$line);
   #(@elements ) = split(/\,/,$line);
   do_process($line,$poll_date);

}  # end while <IN>
$end_time = elapsed_time($start_time);
# --------------------------------- do_process ------------------------
sub do_process
{
# process device
my $line = shift;
my $poll = shift;

chomp $line;
my ($part1,$part2) = split(/\|/,$line);
$part1 =~ s/\,.*$//;
$part1 =~ s/^datacenters.omping\.//;
my ($from_to,$type) = split(/\./,$part1);
$part2 =~ s/\,none//i;
my @times = split(/\,/,$part2);
my $latency;
my $status ='green';
#
#print "part1->$from_to,$type\n";
#print "times->",join(',',@times),"\n";
#<>;
#

my $query;
my $item;

#print "$poll $from_to,$type",",",join(',',@times),"\n";
# update db
my  $where = qq{ `From_To` = '$from_to' and `Type` = '$type' and `Poll_Time` = '$poll'  };
#print $where;
#<>;
  $found = do_seek_where('7t_omping_latency',$where);
#print "f->$found i->$item \n";
#<>;
  if(!($found)) 
    {
    $latency = (sort { $b <=> $a } @times)[0];
    if($latency =~ /None/i)
      {
      $latency = 'NULL';
      }
    $status = get_status($from_to,$type,@times);
    # insert table
    $query = qq{ insert into `7t_omping_latency` SET `From_To` ='$from_to', \
                 `Type` = '$type', `Poll_Time` = '$poll' , \
                 `Latency_Str` = '$part2', `Latency_Status` = '$status' , \
                  `Latency` = $latency; };
print $query;
print "\n----end--\n";
#<>;
    $sth = $dbh->prepare($query);
    $sth->execute;
    $sth->finish; 
    }



return;
}
# --------------------------------- do_seek_where ------------------------

sub do_seek_where
{
my $table = shift;
my $where = shift;
 $found = 0;

my $sth = $dbh->prepare(qq{select * from `$table` \
        where $where });
# execute the select statement
$sth->execute;
while (@row = $sth->fetchrow_array)
{
   print "SEEK FOUND->", join(',',@row),"\n";
 $found = $row[0];
 @last_line = @row;
}
# end the reading of results
$sth->finish;

return $found;
}


# ---------------------------- do_update_record ------------------------
sub do_update_record
{
my $table = shift;

my $set_str = shift;
my $where = shift;

$sth = $dbh->prepare(qq{update `$table` SET $set_str \
        where $where });
# execute above statement
$sth->execute;

$sth->finish;
}


# -------------------------------- get_poll_date ---------------------------
sub get_poll_date
{
my $file = shift;
my $date_string = ctime(stat($file)->mtime);
(undef,$month,$day,$time,$year) = split(/\s+/,$date_string);
%mon2num = qw(
  jan 01  feb 02  mar 03  apr 04  may 05  jun 06
  jul 07  aug 08  sep 09  oct 10 nov 11 dec 12
);
($hr,$min) = split(/\:/,$time);
$mon = $mon2num{ lc substr($month, 0, 3) };

my $poll_date = "$year-$mon-$day $hr:$min";

# print "file $file updated at $poll_date\n";
# <>;

return $poll_date;
}
# ------------------------------ elapsed_time ----------------------------

sub elapsed_time

{
my $start_time = shift;
my $end_time = localtime->hour()*3600 + localtime->min()*60 + localtime->sec();
my $min = (split(/\./,(($end_time - $start_time)/60)))[0];
my $sec = ($end_time - $start_time) - ($min *60);

if($start_time >0)
  {
   print "processing time => ", $min,":",$sec, "\n";
  }

return $end_time;
}
# -------------------------------- get_status --------------------------
sub get_status
{
my $fromto = shift;
my $type = shift;
my @times = @_;
my $color = 'green';
# need to get threshhold
# truncate fromto 15 characters

$fromto = substr( $fromto, 0, 14 );
my $where = qq{ `From_To` ='$fromto' and `Type` = '$type'};
#print "where ->$where \n";
#<>;
my $found = do_seek_where('7t_omping_latency_ref',$where);
if($found)
  {
  my $tresh = $last_line[4];
  my $i =0;
  foreach my $item (@times)
     {
     if($item >=$tresh)
       {
        $i++;
       }
     }  
    if($i>3)
      {
      $color = 'red';
      }
   else
     {
        if($i>=1)
          {
          $color = 'yellow';
          }

     }
       
  }


return $color;
}






