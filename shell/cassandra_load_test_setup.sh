#!/bin/bash
 yes | mdadm -C /dev/md0 --level raid0 --raid-devices=2 /dev/sdc /dev/sdd &&
       mkfs.ext4 /dev/md0 &&
       touch /etc/mdadm.conf &&
       echo 'DEVICES /dev/sdc /dev/sdd' > /etc/mdadm.conf &&
       mdadm --detail --scan >> /etc/mdadm.conf &&
       mkdir -p /var/lib/cassandra/ &&
       mount /dev/md0 /var/lib/cassandra/

sudo yum -y --nogpgcheck install kernel-devel-2.6.32-358.el6
sudo yum -y --nogpgcheck install make gcc libaio-devel libaio
wget http://freecode.com/urls/3aa21b8c106cab742bf1f20d60629e3f
mv 3aa21b8c106cab742bf1f20d60629e3f fio-2.1.10.tar.gz
tar xvzf fio-2.1.10.tar.gz
cd fio-2.1.10
./configure && make && make install && make clean && cd
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=/var/lib/cassandra/test --bs=4k --iodepth=64 --size=96G --readwrite=randrw --rwmixread=50