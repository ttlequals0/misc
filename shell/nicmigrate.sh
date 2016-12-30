#!/bin/bash
octet=$1
hostname=gla2wks$octet
sed -i "s/HOSTNAME=.*/HOSTNAME=$hostname/" /etc/sysconfig/network
rm -fv `ls /etc/sysconfig/network-scripts/ifcfg-* | grep -v lo`
cat >> /etc/hosts <<EOF
10.192.2.$octet $hostname.pi.domain $hostname
EOF
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE=eth0
TYPE=Ethernet
BOOTPROTO=static
HWADDR=`cat /etc/udev/rules.d/*-persistent-net.rules | grep eth0 | perl -ne 'print /((?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2})/'`
IPADDR=10.192.2.$octet
NETMASK=255.255.252.0
GATEWAY=10.192.0.1
IPV6INIT=no
MTU=1500
NM_CONTROLLED=no
ONBOOT=yes
EOF
cat > /etc/sysconfig/network-scripts/ifcfg-vlan3132 <<EOF
VLAN=yes
VLAN_NAME_TYPE=VLAN_PLUS_VID_NO_PAD
DEVICE=vlan3132
PHYSDEV=eth0
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=10.192.34.$octet
NETMASK=255.255.252.0
IPV6INIT=no
USERCTL=no
EOF
cat > /etc/sysconfig/network-scripts/ifcfg-vlan3136 <<EOF
VLAN=yes
VLAN_NAME_TYPE=VLAN_PLUS_VID_NO_PAD
DEVICE=vlan3136
PHYSDEV=eth0
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=10.192.38.$octet
NETMASK=255.255.252.0
IPV6INIT=no
USERCTL=no
EOF
cat > /etc/sysconfig/network-scripts/ifcfg-vlan3148 <<EOF
VLAN=yes
VLAN_NAME_TYPE=VLAN_PLUS_VID_NO_PAD
DEVICE=vlan3148
PHYSDEV=eth0
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=10.192.50.$octet
NETMASK=255.255.252.0
IPV6INIT=no
USERCTL=no
EOF
cat > /etc/sysconfig/network-scripts/ifcfg-vlan3152 <<EOF
VLAN=yes
VLAN_NAME_TYPE=VLAN_PLUS_VID_NO_PAD
DEVICE=vlan3152
PHYSDEV=eth0
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=10.192.54.$octet
NETMASK=255.255.252.0
IPV6INIT=no
USERCTL=no
EOF
cat > /etc/rc.local <<EOF
#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.
touch /tmp/.deployed
/sbin/ip link set lo multicast on
/sbin/ip link set eth0 multicast on
/sbin/ip link set vlan3132 multicast on
/sbin/ip link set vlan3136 multicast on
/sbin/ip link set vlan3148 multicast on
touch /var/lock/subsys/local
# Run post-reboot guest customization
/bin/sh /root/.customization/post-customize-guest.sh
exit 0
EOF
rm -fv /etc/udev/rules.d/*-persistent-net.rules
bash -c "echo net.ipv4.conf.lo.rp_filter=0 >> /etc/sysctl.conf && 
sysctl -p"
bash -c "echo net.ipv4.conf.eth0.rp_filter=0 >> /etc/sysctl.conf && 
sysctl -p"
bash -c "echo net.ipv4.conf.vlan3132.rp_filter=0 >> /etc/sysctl.conf && 
sysctl -p"
bash -c "echo net.ipv4.conf.vlan3136.rp_filter=0 >> /etc/sysctl.conf && 
sysctl -p"
bash -c "echo net.ipv4.conf.vlan3148.rp_filter=0 >> /etc/sysctl.conf && 
sysctl -p"
print $octet
reboot now
