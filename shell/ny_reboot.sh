#!/bin/bash

FILE=$1

echo  -n "Enter your password: "
read -s -r SSHPASS

for server in $(cat "$FILE")
	do		
		SSHOPT="-o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=6 -t -t -l root"
		sshpass -p "$SSHPASS" ssh $SSHOPT "$server" "init 6" 
done
