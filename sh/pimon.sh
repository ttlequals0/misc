#!/bin/bash
## Script to monitor reachability of Raspberry Pi and sends
## Pushover notifaction when down.

HOST="example.ttlequals.com"
PINGCOUNT=4
SLEEPTIME=60
nl=$'\n'
JOB=PI_Monitor
TOKEN=
USER=

while :
  do
   MSG=$(echo "Host : $HOST is down (ping failed) at $(date)")
   alive=$(ping -c $PINGCOUNT $HOST | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')
    if [ $alive -eq 0 ]; then
    curl -s \
     -F "token=$TOKEN" \
     -F "user=$USER" \
     -F "message=$JOB${nl}$MSG" \
     https://api.pushover.net/1/messages
     echo ${nl}
    fi
    sleep $SLEEPTIME
done
