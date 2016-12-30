#!/bin/bash

#Stop logging services.
/sbin/service rsyslog stop
/sbin/service auditd stop

#Remove old kernels
/bin/package-cleanup --oldkernels --count=1

#Clean yum.
/usr/bin/yum clean all

#Force the logs to rotate & remove old logs
/usr/sbin/logrotate –f /etc/logrotate.conf
/bin/rm –f /var/log/*-???????? /var/log/*.gz
/bin/rm -f /var/log/dmesg.old
/bin/rm -rf /var/log/anaconda

#Truncate the audit logs
/bin/cat /dev/null > /var/log/audit/audit.log
/bin/cat /dev/null > /var/log/wtmp
/bin/cat /dev/null > /var/log/lastlog
/bin/cat /dev/null > /var/log/grubby

#Remove udev persistent device rules
/bin/rm -f /etc/udev/rules.d/70*

#remove MAC and UUIDs
/bin/sed -i ‘/^(HWADDR|UUID)=/d’ /etc/sysconfig/network-scripts/ifcfg-eth0

#Clean /tmp out.
/bin/rm –rf /tmp/*
/bin/rm –rf /var/tmp/*

#Remove the SSH host keys
/bin/rm –f /etc/ssh/*key*

#Remove the root user’s shell history 
/bin/rm -f ~root/.bash_history
unset HISTFILE

#Remove the root user’s SSH history
/bin/rm -rf ~root/.ssh/
/bin/rm -f ~root/anaconda-ks.cfg

#shutdown 
init 0
