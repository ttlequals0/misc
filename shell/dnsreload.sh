#!/bin/bash

ssh mon2 -t "cd /etc/ndjbdns && sudo  git pull && sudo ./dnsrecompile.sh && sleep 5 && sudo /sbin/service tinydns start"
ssh tools2 -t "cd /etc/ndjbdns && sudo  git pull && sudo ./dnsrecompile.sh && sleep 5 && sudo /sbin/service tinydns start"
ssh repo -t "cd /etc/ndjbdns && sudo  git pull && sudo ./dnsrecompile.sh && sleep 5 &&  sudo /sbin/service tinydns start"
