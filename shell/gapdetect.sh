#!/bin/bash
##Crontab
#0 0 * * *  /home/dkrachtus/gapdetect.sh 2>&1
#59 23 * * * pkill gapdetect.sh 2>&1

unset min
while : ; 
	do count1=$(grep -i "gap" /var/log/debesys/md_client_edgeserver.log |wc -l) ;
	sleep 60 ;
	count2=$(grep -i "gap" /var/log/debesys/md_client_edgeserver.log |wc -l);  	
	$((min++)) &>/dev/null ; 	
	echo "$(date +%FT%T): Minute: $min: Gaps logged Delta: $(($count2-$count1))" ; 
done >> /home/dkrachtus/gapdetect.$(date +%F).log

