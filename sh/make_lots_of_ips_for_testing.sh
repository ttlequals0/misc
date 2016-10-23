#!/bin/bash -x

FILE="$1"
DEV_LABEL=0
while read IP OTHER
do
        DEV_LABEL=$((DEV_LABEL+1))
        ip addr add ${IP}/22 brd 10.143.3.255 dev eth0 label eth0:${DEV_LABEL}
        ip rule add from ${IP} table ${DEV_LABEL}
        ip route add default via 10.143.0.1 dev eth0:${DEV_LABEL} table ${DEV_LABEL}
done < "${FILE}"
ip route flush cache
