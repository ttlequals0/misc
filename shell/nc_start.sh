#!/bin/bash

FILE=$1

echo  -n "Enter your password: "
read -s -r SSHPASS



for servers in $(cat $1)
	do
		startnc="nc -l -k 443 &"
		SSHOPT="-o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=3 -t -t -l root"

		sshpass -p "$SSHPASS" ssh $SSHOPT "$servers" "bash -s" < ./startnc.sh
done
