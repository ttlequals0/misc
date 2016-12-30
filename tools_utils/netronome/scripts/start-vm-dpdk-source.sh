#!/bin/bash

pktsize="$1"

if [ ! -f /var/opt/bdf-ns-vf.txt ]; then
  echo "ERROR: Missing PCIe bus/device/func file"
  echo "       First use: setup-vm-vf-iface.sh <vm ipa> int nfp_uio"
  exit -1
fi

if [ "$pktsize" == "" ]; then
  echo "ERROR: please specify packet size"
  exit -1
fi

cmd="trafgen"
# DPDK EAL configuration
cmd="$cmd -n 4 -c 3"
cmd="$cmd --socket-mem 256"
cmd="$cmd --proc-type auto"
cmd="$cmd --file-prefix trafgen_source_"
cmd="$cmd -d /opt/netronome/lib/librte_pmd_nfp_net.so"
cmd="$cmd -w $(cat /var/opt/bdf-ns-vf.txt)"
# Delimiter between EAL arguments and application arguments
cmd="$cmd --"
# Port bit-mask
cmd="$cmd --portmask 1"

# Benchmark Mode
cmd="$cmd --benchmark"

cmd="$cmd --summary /tmp/pkt-source.summary"

# Count (duration of test in seconds, unspecified: indefinitely)
#cmd="$cmd --runtime 3599"
# Ethernet and IP parameters
cmd="$cmd --src-mac 00:11:22:33:44:00"
cmd="$cmd --dst-mac 00:44:33:22:11:00"
cmd="$cmd --src-ip 1.0.0.0"
cmd="$cmd --dst-ip 2.0.0.0"
# Packet Size
cmd="$cmd --packet-size $pktsize"
# Packet Rate (0: full rate)
cmd="$cmd -r 0"
# Transmit Burst Size {1..128} (DPDK: tx_burst_size, default: 32)
cmd="$cmd -t 16"

# Flows within 'Stream' (flows_per_stream, default: 65536)
cmd="$cmd --flows-per-stream 2000"
cmd="$cmd --mac-stride 2000"
cmd="$cmd --ip-stride 2000"
# Number of Streams (number_of_streams, default: 1)
cmd="$cmd --streams 8"
# Number of Repeats of Stream
cmd="$cmd --bursts-per-stream 10"

# Save command line to a file
echo "$cmd" > /tmp/cmdline-pkt-src

# Run command
exec $cmd
