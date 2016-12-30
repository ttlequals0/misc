#!/bin/bash

ovs-vsctl set Open_vSwitch . other_config:max-idle=-1

ovs-vsctl --if-exists del-br br0
ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow13 -- set-fail-mode br0 secure

ovs-vsctl add-port br0 sdn_p0 -- set Interface sdn_p0 ofport_request=1
ovs-vsctl add-port br0 sdn_v0.0 -- set Interface sdn_v0.0 ofport_request=10
ovs-vsctl add-port br0 sdn_v0.1 -- set Interface sdn_v0.1 ofport_request=11
ovs-vsctl add-port br0 sdn_v0.2 -- set Interface sdn_v0.2 ofport_request=12
ovs-vsctl add-port br0 sdn_v0.3 -- set Interface sdn_v0.3 ofport_request=13

ovs-ofctl -O OpenFlow13 del-flows br0

ovs-ofctl -Oopenflow13 add-flow br0 priority=100,in_port=10,actions=1
ovs-ofctl -Oopenflow13 add-flow br0 priority=100,in_port=11,actions=1
ovs-ofctl -Oopenflow13 add-flow br0 priority=100,in_port=12,actions=1
ovs-ofctl -Oopenflow13 add-flow br0 priority=100,in_port=13,actions=1
ovs-ofctl -OOpenFlow13 add-group br0 group_id=0,type=select,bucket=actions=10,\
bucket=actions=11,bucket=actions=12,bucket=actions=13
ovs-ofctl -O OpenFlow13 add-flow br0 priority=100,in_port=1,actions=group:0
ovs-ofctl -Oopenflow13 add-flow br0 priority=0,actions=drop
#ovs-ofctl -O OpenFlow13 dump-flows br0
