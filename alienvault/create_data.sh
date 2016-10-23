#!/bin/sh


# Get current lists
wget --no-host-directories -r http://www.malwaredomainlist.com/mdlcsv.php -O malwaredomainlist.csv

# Parse the lists
./parsemdl.pl
./parseotx.pl

cat mdl.csv > threat_ips.txt
cat otx.csv >> threat_ips.txt 
