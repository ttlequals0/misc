#!/bin/bash

# IP address of VM
vmipa="$1"
# Interface name inside of VM of SR-IOV virtual function
vmifname="$2"
# Interface device driver to attach to the virtual function
ifdrv="$3"

# Location of DPDK bind tool inside VM
bind="/opt/netronome/srcpkg/dpdk-ns/tools/dpdk_nic_bind.py"

# Assymble/build command string to be pass by scp into VM

scr=""
# Make sure the driver is loaded into the kernel
scr="$scr modprobe $ifdrv &&"
# Extract the PCI 'bus/device/function' information of the 'NFP' Virtual Function
scr="$scr bdf=\$($bind --status | sed -rn 's/^(\S+)\s.*Device\s6003.*$/\1/p' | head -1) &&"
# Make sure IPv4 is disable on interface and set it to admin-DOWN
scr="$scr grep $vmifname /proc/net/dev > /dev/null"
scr="$scr   && ifconfig $vmifname 0 down ;"
# Bind the driver to the virtual-function
scr="$scr $bind -b $ifdrv \$bdf ;"
# Save the 'bus/device/function' information for other scripts
scr="$scr echo \$bdf > /var/opt/bdf-ns-vf.txt ;"

# Remotely login to the VM and execute above commands
echo Command string: ssh $vmipa "$scr"
ssh $vmipa "$scr"
