#!/bin/bash
ipaddr=$( /sbin/ip addr |grep eth0 |grep inet |grep 10 |awk '{print $2}' |sed 's/\/22//')
wrongip=$(echo "$ipaddr" |sed 's/\.2/.0/' |sed 's/\./\\\./g') 
rightip=$(echo "$ipaddr" |sed 's/\./\\\./g') 
sudo sed -i -e "s/$wrongip/$rightip/"  /etc/hosts

ipaddr=$( /sbin/ip addr |grep eth0 |grep inet |grep 10 |awk '{print $2}' |sed 's/\/22//') && wrongip=$(echo 10.102.0.30 |sed 's/\./\\\./g') && rightip=$(echo "$ipaddr" |sed 's/\./\\\./g') && sed -i -e "s/$wrongip/$rightip/" /etc/squid/squid.conf && service httpd restart && service squid restart



