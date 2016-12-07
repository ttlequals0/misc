#!/bin/bash

if dmesg |grep 'CIFS' |grep -iq 'inode' ;then
	echo "$(date) : Force Reboot" >> /var/log/cifs_check/out.log
	echo 1 > /proc/sys/kernel/sysrq
	echo b > /proc/sysrq-trigger
else
	echo "$(date) : System OK!" >> /var/log/cifs_check/out.log
fi
