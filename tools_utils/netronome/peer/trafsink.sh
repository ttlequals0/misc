#!/bin/bash

echo 256 > /proc/sys/vm/nr_hugepages
mkdir -p /mnt/huge
grep -q hugetlbfs /proc/mounts || mount -t hugetlbfs nodev /mnt/huge
rm -rf /mnt/huge/*

ovs-ofctl -O OpenFlow13 dump-flows br0

/usr/local/bin/trafgen -n 2 --socket-mem 512 -c 0xffff -d /opt/netronome/lib/librte_pmd_nfp_net.so -w 0000:04:08.4 -w 0000:04:08.5 -w 0000:04:08.6 -w 0000:04:08.7 -- -p 0xff

