#!/bin/bash

if [ ! -f /var/opt/bdf-ns-vf.txt ]; then
  echo "ERROR: Missing PCIe bus/device/func file"
  echo "       First use: setup-vm-vf-iface.sh <vm ipa> int nfp_uio"
  exit -1
fi

cmd="pktcnt"
cmd="$cmd -n 1 -c 3"
cmd="$cmd -d /opt/netronome/lib/librte_pmd_nfp_net.so"
cmd="$cmd -w $(cat /var/opt/bdf-ns-vf.txt)"
cmd="$cmd --"
cmd="$cmd -p 1"

echo $cmd > /tmp/cmdline-pktcnt

exec $cmd
