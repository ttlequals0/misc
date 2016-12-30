#!/bin/bash -x
LOGFILE="/var/tmp/${0##*/}.log"
exec > >(tee ${LOGFILE})
exec 2>&1

bail ()
{
	echo "exiting abnormally"
	exit ${1:="1"}
}

put_me_in_downtime -t 90 -r "solarflare upgrade" || bail 7

service sfptpd stop
initctl stop sfptpd
sleep 5
pgrep sfptpd && bail 6

yum -y --nogpgcheck update ./sfutils-4.7.1.1001-1.x86_64.rpm ./sfptpd-2.2.4.70-1.x86_64.rpm || bail 1

ifdown eth1
ifdown eth0

yum -y --nogpgcheck remove openonload\* || bail 2

yum -y --nogpgcheck install ./openonload-201509-1.el6.x86_64.rpm ./openonload-kmod-$(uname -r | sed "s/\.$(uname -p)//g")-201509-1.el6.x86_64.rpm || bail 3

ifdown eth1
ifdown eth0

onload_tool reload || bail 4

sfupdate -y --write || bail 5

shutdown_delay="30"
echo "a cold boot is now required.  shutting down in ${shutdown_delay} seconds."
sleep ${shutdown_delay} && shutdown -h now
