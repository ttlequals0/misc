#!/bin/bash

# This script will build the Netronome traffic test tool 'trafgen'
# and prepare OVS and DPDK for either traffic generation or termination.

if [ "$1" == "VXLAN" ]; then
  VXLAN="yes"
fi

############################################################
# Build Test-tool application

tar xzvf trafgen.tar.gz -C /root
export RTE_SDK="/opt/netronome/srcpkg/dpdk-ns"
export RTE_TARGET="x86_64-native-linuxapp-gcc"
export RTE_OUTPUT="$HOME/.cache/dpdk/trafgen"
tar xzf trafgen.tar.gz -C /root
mkdir -p $RTE_OUTPUT
make -C $HOME/trafgen
cp -f $RTE_OUTPUT/trafgen /usr/local/bin

############################################################
# Clean-up all existing OVS bridges

for brname in $(ovs-vsctl list-br) ; do
  ovs-vsctl del-br $brname
  sleep 0.5
done

############################################################
# Setup 'Huge Pages'
mkdir -p /mnt/huge
#grep hugetlbfs /proc/mounts \
#  || mount -t hugetlbfs huge /mnt/huge

# Make sure some hugepages are allocated
echo 4096 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

############################################################
# Setup the bridge and attach the physical port

ovs-vsctl add-br br0 \
  -- set Bridge br0 protocols=OpenFlow13

# Flush default NORMAL rule
ovs-ofctl -O OpenFlow13 del-flows br0

ifconfig sdn_p0 0
ifconfig sdn_p0 down
ifconfig sdn_p0 mtu 2000

if [ "$VXLAN" != "" ]; then
  ifconfig sdn_p0 hw ether 02:11:11:00:00:02
  ifconfig sdn_p0 10.1.1.2/24
  ifconfig sdn_p0 up
  # Add Static ARP entry 
  arp -i sdn_p0 -s 10.1.1.1 02:11:11:00:00:01
  ovs-vsctl \
    -- --may-exist add-port br0 vxlt \
    -- set Interface vxlt ofport_request=1 \
    -- set interface vxlt type=vxlan \
       options:local_ip=10.1.1.2 \
       options:remote_ip=10.1.1.1 \
       options:key=1
else
  ifconfig sdn_p0 up
  # Add Physical Port (=1)
  ovs-vsctl add-port br0 sdn_p0 \
    -- set Interface sdn_p0 ofport_request=1
fi

############################################################
# Attach virtual-function ports to bridge

whitelist=""
ofpgrp=""
#for idx in $(seq 0 3) ; do
for idx in $(seq 4 7) ; do
  iface="sdn_v0.$idx"
  # OpenFlow Port Index
  ofpidx=$(( 10 + $idx ))
  # (Domain)/Bus/Device/Function
  bdf=$(ethtool -i $iface | sed -rn 's/^bus-info:.*\s(.*)$/\1/p')
  $RTE_SDK/tools/dpdk_nic_bind.py -b nfp_uio $bdf
  ovs-vsctl add-port br0 $iface \
    -- set Interface $iface ofport_request=$ofpidx
  # Egress Rule (for generated traffic)
  ovs-ofctl -O OpenFlow13 add-flow br0 \
    "in_port=$ofpidx,action=output:1"
  # Ingress Load-balancing list (for terminating traffic)
  ofpgrp="$ofpgrp,bucket=actions=output:$ofpidx"
done

# Configure group
ovs-ofctl -O OpenFlow13 add-group $brname \
  "group_id=1,type=select$ofpgrp"

# Load-balance all traffic received on the physical port ('1')
ovs-ofctl -O OpenFlow13 add-flow $brname \
  "in_port=1,actions=group:1"

############################################################
