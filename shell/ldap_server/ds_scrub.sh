#!/bin/bash
# remove dirsrv from a machine
service dirsrv stop
ps -ef | grep ns-slapd | head -n 1 | tr -s " " | cut -f2 -d" " | xargs kill -9
yum -y remove 389*

rm -rfv /etc/sysconfig/dirsrv-*
rm -rfv /etc/dirsrv
rm -rfv /var/log/dirsrv
rm -rfv /var/lib/dirsrv
rm -rfv /var/lock/dirsrv

yum install -y 389-ds
