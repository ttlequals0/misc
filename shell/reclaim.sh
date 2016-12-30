#!/bin/sh
#ESXI unmap script
DATASTORE=$(esxcli storage filesystem list |grep 3PAR |awk '{print $3}')
LOGFILE=~/unmap.log

echo "----------------------------------------------------" 2>&1 | tee -a  "$LOGFILE"
date 2>&1 | tee -a "$LOGFILE"
hostname 2>&1 | tee -a "$LOGFILE"
if [ ! -z "$DATASTORE" ];
then
	START=$(date +%s)	
	for SAN_STORAGE in $DATASTORE
		do 
		 echo "Running unmap on $SAN_STORAGE"  2>&1 | tee -a "$LOGFILE"
		 esxcli storage vmfs unmap -u "$SAN_STORAGE" 2>&1 | tee -a "$LOGFILE"
		 grep "Unmap: Done" /var/log/hostd.log | grep "$SAN_STORAGE" |awk -F ':' '{print $3 $4}'  2>&1 | tee -a "$LOGFILE"
	done
	END=$(date +%s)
	DIFF=$((END - START))
	MINUTES=$(( DIFF / 60 ))
	echo "It took $MINUTES minutes to complete unmap process..."  2>&1 | tee -a "$LOGFILE"
else
	echo "No Datastores were found."  2>&1 | tee -a "$LOGFILE"
	exit
fi	


