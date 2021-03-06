#!/bin/bash

# OVS commands captured from SDN Autotests
# Test: performance.twodut.dcbu_msb_l2fwd_vm_64k_1k_128_vtov_bidir_4_ipv4_udp
# DUT : r730-dev-09.pa

rm -rf /tmp/sdn-test/logs/monitor-logs_r730-dev-09.pa
mkdir -p /tmp/sdn-test/logs/monitor-logs_r730-dev-09.pa
service irqbalance stop
ip link show dev sdn_ctl
ip addr show dev sdn_ctl
ip link show dev sdn_p0
ip addr show dev sdn_p0
ip link show dev sdn_pkt
ip addr show dev sdn_pkt
ip link show dev sdn_p0
ip addr flush dev sdn_p0
ip link set dev sdn_p0 mtu 1500
ip link set dev sdn_p0 down
ip link set dev sdn_p0 up
ip link show dev sdn_p0
ip addr show dev sdn_p0
ovs-vsctl list-br
ovs-vsctl --may-exist add-br testbr0
ovs-vsctl set bridge testbr0 protocols=OpenFlow13
ovs-vsctl set Open_vSwitch . other_config:max-idle=1500
ovs-vsctl --may-exist add-port testbr0 sdn_v0.0 -- set Interface sdn_v0.0 ofport_request=1
ovs-vsctl --may-exist add-port testbr0 sdn_v0.1 -- set Interface sdn_v0.1 ofport_request=2
ovs-vsctl --may-exist add-port testbr0 sdn_v0.2 -- set Interface sdn_v0.2 ofport_request=3
ovs-vsctl --may-exist add-port testbr0 sdn_v0.3 -- set Interface sdn_v0.3 ofport_request=4
virsh domstate testvm24
virsh start testvm24
virsh domstate testvm25
virsh start testvm25
virsh domstate testvm26
virsh start testvm26
virsh domstate testvm27
virsh start testvm27
virsh vcpupin testvm24 0 2
virsh vcpupin testvm24 1 4
ls /sys/bus/pci/devices/0000:04:08.0/driver/0000:04:08.0/msi_irqs
echo 0000,00000004 > /proc/irq/241/smp_affinity
cat /proc/irq/241/smp_affinity
echo 0000,00000004 > /proc/irq/307/smp_affinity
cat /proc/irq/307/smp_affinity
echo 0000,00000004 > /proc/irq/308/smp_affinity
cat /proc/irq/308/smp_affinity
virsh vcpupin testvm25 0 6
virsh vcpupin testvm25 1 8
ls /sys/bus/pci/devices/0000:04:08.1/driver/0000:04:08.1/msi_irqs
echo 0000,00000040 > /proc/irq/242/smp_affinity
cat /proc/irq/242/smp_affinity
echo 0000,00000040 > /proc/irq/309/smp_affinity
cat /proc/irq/309/smp_affinity
echo 0000,00000040 > /proc/irq/310/smp_affinity
cat /proc/irq/310/smp_affinity
virsh vcpupin testvm26 0 10
virsh vcpupin testvm26 1 12
ls /sys/bus/pci/devices/0000:04:08.2/driver/0000:04:08.2/msi_irqs
echo 0000,00000400 > /proc/irq/243/smp_affinity
cat /proc/irq/243/smp_affinity
echo 0000,00000400 > /proc/irq/311/smp_affinity
cat /proc/irq/311/smp_affinity
echo 0000,00000400 > /proc/irq/312/smp_affinity
cat /proc/irq/312/smp_affinity
virsh vcpupin testvm27 0 14
virsh vcpupin testvm27 1 16
ls /sys/bus/pci/devices/0000:04:08.3/driver/0000:04:08.3/msi_irqs
echo 0000,00004000 > /proc/irq/244/smp_affinity
cat /proc/irq/244/smp_affinity
echo 0000,00004000 > /proc/irq/313/smp_affinity
cat /proc/irq/313/smp_affinity
echo 0000,00004000 > /proc/irq/314/smp_affinity
cat /proc/irq/314/smp_affinity
ovs-ofctl -OOpenFlow13 add-flows testbr0 /tmp/sdn-test/r730-dev-09.pa_l2fwd_msb.flows
screen -ls
screen -dmS monitors
screen -ls
screen -S 143348.monitors -X stuff '/tmp/sdn-test/monitor performance.twodut.dcbu_msb_l2fwd_vm_64k_1k_128_vtov_bidir_4_ipv4_udp_r730-dev-09.pa_beagle_rev3290_100_throughput /tmp/sdn-test/logs/monitor-logs_r730-dev-09.pa testbr0 3600 S,A sdn_v0.0 sdn_v0.1 sdn_v0.2 sdn_v0.3\n'
pgrep monitor
/bin/kill -SIGTERM 141577
/bin/kill -SIGTERM 141877
/bin/kill -SIGTERM 143369
/bin/kill -SIGTERM 144490
/bin/kill -SIGTERM 144491
/bin/kill -SIGTERM 144492
/bin/kill -SIGTERM 144493
/bin/kill -SIGTERM 144495
cd /tmp/sdn-test && tar cfz /tmp/sdn-test/performance.twodut.dcbu_msb_l2fwd_vm_64k_1k_128_vtov_bidir_4_ipv4_udp_r730-dev-09.pa_beagle_rev3290_logs.tar.gz logs
virsh shutdown testvm24
virsh shutdown testvm25
virsh shutdown testvm26
virsh shutdown testvm27
virsh domstate testvm24
virsh domstate testvm24
virsh domstate testvm25
virsh domstate testvm26
virsh domstate testvm27
