#!/bin/bash

# This script configures both the Net-to-VM and VM-to-Net use case.
# It optionally also configures a VXLAN tunnel endpoint.

if [ "$1" == "VXLAN" ]; then
  VXLAN="yes"
fi

#set -x

# Remove the existing br0 (if it exists)
ovs-vsctl --if-exists del-br br0

# Recreate the bridge
ovs-vsctl add-br br0

# Remove the default NORMAL rule
ovs-ofctl del-flows br0

if [ "$VXLAN" != "" ]; then
  l_ipaddr="10.1.1.1"
  r_ipaddr="10.1.1.2"
  vxifname="vxlt"
  ifconfig sdn_p0 down
  # Set MAC address of physical port
  ifconfig sdn_p0 hw ether 02:11:11:00:00:01
  ifconfig sdn_p0 mtu 2000
  ifconfig sdn_p0 up $l_ipaddr/24
  # Add Static ARP entry to peer
  arp -i sdn_p0 -s $r_ipaddr 02:11:11:00:00:02
  ovs-vsctl \
    -- --may-exist add-port br0 $vxifname \
    -- set Interface $vxifname ofport_request=1 \
    -- set interface $vxifname type=vxlan \
       options:local_ip=$l_ipaddr \
       options:remote_ip=$r_ipaddr \
       options:key=1
else
  ifconfig sdn_p0 0
  # Add Physical port (=1)
  ovs-vsctl add-port br0 sdn_p0 \
    -- set Interface sdn_p0 ofport_request=1
fi

# Add VM ports and set the port numbers to 10..13
ovs-vsctl add-port br0 sdn_v0.0 -- set Interface sdn_v0.0 ofport_request=10
ovs-vsctl add-port br0 sdn_v0.1 -- set Interface sdn_v0.1 ofport_request=11
ovs-vsctl add-port br0 sdn_v0.2 -- set Interface sdn_v0.2 ofport_request=12
ovs-vsctl add-port br0 sdn_v0.3 -- set Interface sdn_v0.3 ofport_request=13

if [ "$SETUP_DEFAULT_RULES" != "" ]; then
  # Setup default egress rules
  ovs-ofctl add-flow br0 "in_port=10,action=output:1"
  ovs-ofctl add-flow br0 "in_port=11,action=output:1"
  ovs-ofctl add-flow br0 "in_port=12,action=output:1"
  ovs-ofctl add-flow br0 "in_port=13,action=output:1"

  # Setup default ingress rules
  ovs-ofctl add-flow br0 \
    "in_port=1,dl_dst=00:00:00:00:00:00/00:00:00:00:00:03,action=output=10"
  ovs-ofctl add-flow br0 \
    "in_port=1,dl_dst=00:00:00:00:00:01/00:00:00:00:00:03,action=output=11"
  ovs-ofctl add-flow br0 \
    "in_port=1,dl_dst=00:00:00:00:00:02/00:00:00:00:00:03,action=output=12"
  ovs-ofctl add-flow br0 \
    "in_port=1,dl_dst=00:00:00:00:00:03/00:00:00:00:00:03,action=output=13"
fi

#set +x
