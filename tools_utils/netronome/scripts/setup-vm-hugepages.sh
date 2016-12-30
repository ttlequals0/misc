#!/bin/bash

# Setup hugepages feature on VM

ipaddr="$1"

scr=""
scr="$scr mkdir -p /mnt/huge ;"
scr="$scr ( grep hugetlbfs /proc/mounts > /dev/null ||"
scr="$scr mount -t hugetlbfs huge /mnt/huge ) ;"
scr="$scr echo 512 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"

echo Command string: ssh $ipaddr "$scr"
ssh $ipaddr "$scr"
