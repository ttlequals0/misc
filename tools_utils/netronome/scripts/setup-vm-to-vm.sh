#!/bin/bash

# Bridge name
brname="br0"

# Remove the existing bridge (if it exists)
ovs-vsctl --if-exists del-br $brname

# Add the bridge back (allow for OpenFlow 1.3 features)
ovs-vsctl add-br $brname \
  -- set Bridge $brname protocols=OpenFlow13

# Remove the default NORMAL rule
ovs-ofctl -O OpenFlow13 del-flows $brname

# Attach sdn_v0.0 - sdn_v0.3 to the bridge
for idx in $(seq 0 3); do
  iface="sdn_v0.$idx"
  ofpidx=$(( 10 + $idx ))
  ovs-vsctl add-port $brname $iface \
    -- set Interface $iface ofport_request=$ofpidx
done
