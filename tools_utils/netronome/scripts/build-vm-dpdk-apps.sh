#!/bin/bash

vmipa="$1"
shift 1
applist="$*"

########################################

. $NS_SHARED_SETTINGS
. $NS_PKGS_DIR/shared/vm-utilities.sh
. $NS_PKGS_DIR/shared/dpdk-utils.sh

########################################
# Usage:
#
# build-vm-dpdk-apps.sh 10.1.7.1 trafgen l2fwd
#
########################################

if [ "$1" == "" ] || [ "$1" == "--help" ]; then
  echo "Usage: <vmipa> <application> [<application> ...]"
  exit 0
fi

########################################

rsync -aq -R $NS_PKGS_DIR/./dpdk/src $vmipa:

# The 'sink' application is in pkgs/dpdk/src
#rsync -aq -R /opt/netronome/samples/dpdk/./sink $vmipa:dpdk/src

rsync -aq /opt/netronome/srcpkg/dpdk-ns/examples/* $vmipa:dpdk/src

scr=""
scr="$scr export RTE_SDK=/opt/netronome/srcpkg/dpdk-ns &&"
scr="$scr export RTE_TARGET=x86_64-native-linuxapp-gcc &&"
for appname in $applist ; do
  tooldir="dpdk/src/$appname"
  scr="$scr echo 'Build '$appname &&"
  scr="$scr export RTE_OUTPUT=\$HOME/.cache/dpdk/build/$appname &&"
  scr="$scr mkdir -p \$RTE_OUTPUT &&"
  scr="$scr make --no-print-directory -C \$HOME/$tooldir &&"
  scr="$scr cp \$RTE_OUTPUT/$appname /usr/local/bin &&"
done
scr="$scr echo 'Success'"

exec ssh $vmipa "$scr"
