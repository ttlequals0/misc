#!/usr/bin/perl -w

#Format of list:   date/time, domain (either domain or a "-"), IP, reverse lookup, description, registrant, ASN
#Values we care about: domain, IP, description (fields 1, 2, 4 zero-based)

unless (open INPUT, "malwaredomainlist.csv") {
  die "Cannot find input file: $!";
  }
unless (open OUTPUT, ">mdl.csv") {
  die "Cannot open output file: $!";
  }

while (<INPUT>) {
  chomp;
  my @line = split(/","/);
  #print "@line\n";
  #exit;
  # skip blank lines
  next if /^(\s)*$/;
  # if the first field contains only a hyphen then the URL data lives in the second field
  if ( $line[1] =~ /^-$/ ) {
    # skip lines with more than 992 chars (active list string limit is 1,000; subtract 8 for "https://")
    next if (length($line[2]) > 992);
    $line[2] =~ s/^(http|https):\/\///;
    # replace any sneaky backslashes
    $line[2] =~ s/\\//g;
    # remove any trailing whitespace
    $line[2] =~ s/\s+$//g;
    # escape double quotes
    $line[2] =~ s/"/%22/g;
    #just care about IP, carve it out
    $_ = $line[2];
    s/\/.*//g;
    s/:.*//g;
    #print "$_\n";
    $line[2] = $_;
    print OUTPUT "$line[1]#$line[2]#$line[4]\n"; 
  } else {
    # skip lines with more than 992 chars (active list string limit is 1,000; subtract 8 for "https://")
    next if (length($line[1]) > 992);
    # replace any sneaky backslashes
    $line[1] =~ s/\\//g;
    # remove any trailing whitespace
    $line[1] =~ s/\s+$//g;
    # escape double quotes
    $line[1] =~ s/"/%22/g;
    print OUTPUT "$line[1]#$line[2]#$line[4]\n"; 
  }
}
close (INPUT);
close (OUTPUT);
