#!/bin/bash

if [[ $# -ne 1 ]]; then
	echo -e "Usage: $0 Server_list" # use ~/tmp/ny_list
	exit 1;
fi

SERVERS="$1"
SSHOPT="-o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=3 -t -t"

echo  -n "Enter your password: "
read -s -r SSHPASS

(cat "$SERVERS"; echo) | while IFS=',' read -r HOST VLANIP 
do
echo "$HOST $VLANIP" 

	VLANINFO="VLAN=yes
		VLAN_NAME_TYPE=VLAN_PLUS_VID_NO_PAD
		DEVICE=vlan903
		PHYSDEV=eth1
		BOOTPROTO=static
		ONBOOT=yes
		TYPE=Ethernet
		IPADDR=$VLANIP
		NETMASK=255.255.255.128
		IPV6INIT=no
		USERCTL=no"
	


	NEWFILE=/etc/sysconfig/network-scripts/ifcfg-vlan903
	VLANFILE="sudo touch $NEWFILE"
	UP903="sudo ifup vlan903"
	

	sshpass -p "$SSHPASS" ssh $SSHOPT "$HOST" "$VLANFILE && echo '$VLANINFO'| sed -e 's/^[ \t]*//' | sudo tee -a $NEWFILE  > /dev/null || exit 1 && $UP903" 

done

sshpass -p "$SSHPASS" ssh $SSHOPT 10.113.0.41 "~/ping903.sh"