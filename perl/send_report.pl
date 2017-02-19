#!/usr/bin/perl -w
$file = $ARGV[0];
open(IN, "$file") || die "cant open $file file \n";
@lines = <IN>;
close(IN);

$var ="From:  "; 
$var .= '<.local>';
$var .= "\n";
$var .= qq{Subject: $file report 
MIME-Version: 1.0
Content-Type: multipart/mixed;
        boundary="XXXXboundary text"

This is a multipart message in MIME format.

--XXXXboundary text
Content-Type: text/plain

$file attached

--XXXXboundary text
Content-Type: text/plain;
Content-Disposition: attachment;
        filename="$file"

};
foreach $line (@lines)
{
 $var .= $line;
}

$var .= qq{
--XXXXboundary text--

};
$file = "t-mail";
open(OUT, ">$file") || die "cant open $file file \n";
print OUT $var;
close(OUT);
if(!(defined($ARGV[1])))
  {
  #system("/usr/lib/sendmail jk\@ies.com < $file");

  }
else
 {
 
  system("/usr/lib/sendmail $ARGV[1]\@ogies.com < $file");
  print "Mail sent to ",$ARGV[1]," \n";
 }
system("/usr/lib/sendmail \@ogies.com < $file");
# print $var;


