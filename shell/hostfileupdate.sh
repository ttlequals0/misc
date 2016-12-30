#!/bin/bash

echo  -n "Enter your password: "
read -s -r SSHPASS

for servers in $(cat ./list)
	do
		SSHOPT="-o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=3 -t -t"


		sshpass -p "$SSHPASS" ssh $SSHOPT "$servers" "bash -s" < 1line.sh
done