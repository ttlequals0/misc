#!/bin/bash

iflist=""

iflist=$(cat /proc/net/dev \
  | sed -rn 's/^(sdn_p.):.*/\1/p' \
  | sort)

iflist="$iflist sdn_pkt"
#iflist="$iflist sdn_ctl"

for idx in $(seq 0 15); do
  iflist="$iflist sdn_v0.$idx"
done

#for idx in $(seq 0 15); do
#  iflist="$iflist sdn_v1.$idx"
#done

rate --long -i 1 --norm --list-drop --pktsize --reset --total $iflist
