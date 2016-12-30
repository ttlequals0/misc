#!/bin/bash

# This script start the Netronome traffic test tool either as a
# traffic sink (with the SINK command line argument) or as a
# traffic source (with the packet size on the command line).

if [ "$1" == "" ]; then
  echo "ERROR: Please specify packet size (or the keyword SINK)"
  exit -1
fi
if [ "$1" == "SINK" ]; then
  mode="SINK"
else
  mode="SOURCE"
  pktsize="$1"
fi

############################################################
# Compose the port list (DPDK EAL white list)

whitelist=""
for idx in $(seq 0 3) ; do
  iface="sdn_v0.$idx"
  # (Domain)/Bus/Device/Function
  bdf=$(ethtool -i $iface | sed -rn 's/^bus-info:.*\s(.*)$/\1/p')
  # White list (port list) for DPDK application
  whitelist="$whitelist -w $bdf"
done

############################################################
# Setup Command Line

cmd="/usr/local/bin/trafgen"

cmd="$cmd -n 1"
cmd="$cmd -c 0xffff"
cmd="$cmd -d /opt/netronome/lib/librte_pmd_nfp_net.so"
# Add port list (in the form of an EAL white list)
cmd="$cmd $whitelist"
cmd="$cmd --"
# Set the port mask to all eight ports
cmd="$cmd -p 0xf"

cmd="$cmd --summary /tmp/trafgen-summary.txt"

case "$mode" in
  "SOURCE")
    # 'Benchmark' mode (traffic generator)
    cmd="$cmd -b"
    # Duration in seconds (1..3599)
    cmd="$cmd -Q 3599"
    # Source IP address
    cmd="$cmd -u 10.99.0.0"
    # Destination IP address
    cmd="$cmd -v 10.0.0.0"
    # Source MAC
    cmd="$cmd -w 02:01:00:00:00:00"
    # Destination MAC
    cmd="$cmd -x 02:00:00:00:00:00"
    # Packet Size
    cmd="$cmd -z $pktsize"
    # Packet Rate (per thread)
    cmd="$cmd -r 0"
    # Transmit Burst Size {1..128} (DPDK: tx_burst_size, default: 32)
    cmd="$cmd -t 16"
    # Flows within 'Stream' (flows_per_stream, default: 65536)
    cmd="$cmd -y 1000000"
    # Number of Streams (number_of_streams, default: 1)
    cmd="$cmd -i 1"
    # Number of Repeats of Stream
    cmd="$cmd -j 1"

# cmd="$cmd -g 1 -k 1"

    ;;
  "SINK")
    ;;
esac

# Capture the full command in a file
echo $cmd > /tmp/cmdline-1M-$mode

# Terminate shell and execute command
exec $cmd
