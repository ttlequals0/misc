#!/bin/bash

echo "What is this machine's hostname?  "
read MY_HOSTNAME

INITIATORNAME="iqn.1994-05.com.domain:${MY_HOSTNAME}"
VOLUMEGROUP="vg_$(sed 's/-//g' <<< "${MY_HOSTNAME}")"

echo -e "\nBased on hostname we'll use the following settings:\niSCSI Initiator Name: ${INITIATORNAME}\nVolume Group Name: ${VOLUMEGROUP}\n"

IPADDRESS="$(ip address | awk '{ if( $1 == "inet" && $2 ~ /10\./ ){ split($2,arr,"/"); print arr[1] }}')"

[[ $(wc -l <<< "${IPADDRESS}") -lt 1 ]] && { echo "No ip addresses found.  I must have had problems setting up the network."; exit 1; }

[[ $(wc -l <<< "${IPADDRESS}") -gt 1 ]] && { echo -e "I found more than one ip address on this machine.\n\n${IPADDRESS}\n\nI don't know what to do."; exit 1; }

case "${IPADDRESS}" in
	10.102.*)
		INFRASERVER="10.102.0.29"
		ISCSIPORTAL="10.102.16.11"
		;;

	10.111.*)
		INFRASERVER="10.111.0.28"
		ISCSIPORTAL="10.111.16.11"
		;;

	10.113.*)
		INFRASERVER="10.113.0.28"
		ISCSIPORTAL="10.113.16.11"
		;;

	10.127.*)
		INFRASERVER="10.127.0.28"
		ISCSIPORTAL="10.127.16.11"
		;;

	10.204.*)
		INFRASERVER="10.204.0.29"
		ISCSIPORTAL="10.204.16.11"
		;;

	10.205.*)
		INFRASERVER="10.205.0.28"
		ISCSIPORTAL="10.205.16.11"
		;;

	10.206.*)
		INFRASERVER="10.206.0.28"
		ISCSIPORTAL="10.206.16.11"
		;;

	*)
		echo "Unable to determine which server to use based off of ip address ${IPADDRESS}"
		exit 1
esac

echo -e "Using infrastructure server: ${INFRASERVER}\nUsing iSCSI portal: ${ISCSIPORTAL}\n"

curl http://${INFRASERVER}/bootstrap/diskmigration/hpvsa-6.6.ko > /tmp/hpvsa.ko

echo "Setting up iSCSI"

mkdir -p /etc/iscsi

echo "iscsid.startup = /usr/sbin/iscsid
node.startup = automatic
node.leading_login = No
node.session.timeo.replacement_timeout = 120
node.conn[0].timeo.login_timeout = 15
node.conn[0].timeo.logout_timeout = 15
node.conn[0].timeo.noop_out_interval = 5
node.conn[0].timeo.noop_out_timeout = 5
node.session.err_timeo.abort_timeout = 15
node.session.err_timeo.lu_reset_timeout = 30
node.session.err_timeo.tgt_reset_timeout = 30
node.session.initial_login_retry_max = 8
node.session.cmds_max = 128
node.session.queue_depth = 32
node.session.xmit_thread_priority = -20
node.session.iscsi.InitialR2T = No
node.session.iscsi.ImmediateData = Yes
node.session.iscsi.FirstBurstLength = 262144
node.session.iscsi.MaxBurstLength = 16776192
node.conn[0].iscsi.MaxRecvDataSegmentLength = 262144
node.conn[0].iscsi.MaxXmitDataSegmentLength = 0
discovery.sendtargets.iscsi.MaxRecvDataSegmentLength = 32768
node.conn[0].iscsi.HeaderDigest = None
node.session.nr_sessions = 1
node.session.iscsi.FastAbort = Yes" > /etc/iscsi/iscsid.conf

echo "InitiatorName=${INITIATORNAME}" > /etc/iscsi/initiatorname.iscsi

ISCSI_TARGET_LIST="$(iscsiadm -m discovery -t sendtargets -p ${ISCSIPORTAL}:3260)"

while read PPPPORTAL TTTTARGET OTHER
do
	iscsiadm -m node --targetname ${TTTTARGET} -p ${PPPPORTAL} --login
done <<< "${ISCSI_TARGET_LIST}"

iscsiadm -m session -R

sleep 10

echo -e "\n\n\n\n"
ls -l /dev/disk/by-path/ip-*iscsi*
echo -e "\nDo you see the iSCSI LUN(s)?\nIf not, Ctrl-C now and figure it out."
echo "Enter to continue."
read

echo "Looking for RAID controller"

FOUND_KNOWN_RAID=0
PARTITION="UNKNOWN"
RAID_PCI="$(lspci -D | grep "RAID bus controller")"
RAID_PCI_ADDR="$(cut -f1 -d" " <<< "${RAID_PCI}")"

[[ $(wc -l <<< "${RAID_PCI}") -lt 1 ]] && { echo "I didn't find any RAID controllers."; exit 1; }
[[ $(wc -l <<< "${RAID_PCI}") -gt 1 ]] && { echo "I found more than one RAID controller."; exit 1; }

grep -q "Hewlett-Packard Company Device 0045" <<< "${RAID_PCI}"
if [[ $? -eq 0 ]]
then
	FOUND_KNOWN_RAID=1
	PARTITION=1
	echo "Found crappy HP firmware raid"
	echo ""
	echo ""

	insmod /tmp/hpvsa.ko
fi

grep -q "Intel Corporation C600/X79" <<< "${RAID_PCI}"
if [[ $? -eq 0 ]]
then
	FOUND_KNOWN_RAID=1
	PARTITION=2
	echo "Found nice hardware RAID controller"
	echo ""
	echo ""

	insmod /tmp/hpvsa.ko
	sleep 10

	lspci -vvv -s ${RAID_PCI_ADDR} | grep -q hpvsa
	HPVSA_BROKEN=$?

	if [[ ${HPVSA_BROKEN} -eq 1 ]]
	then
		echo ${RAID_PCI_ADDR} > /sys/bus/pci/drivers/ahci/unbind
		modprobe -r ahci
		echo ${RAID_PCI_ADDR} > /sys/bus/pci/drivers/hpvsa/bind
	fi
fi

[[ ${FOUND_KNOWN_RAID} -ne 1 || ${PARTITION} == "UNKNOWN" ]] && { echo -e "I found a RAID controller, but I can't identify it.\n${RAID_PCI}"; exit 1; }

sleep 10

DISK="/dev/disk/by-path/pci-${RAID_PCI_ADDR}-scsi-0:0:0:0"
DISK_PART="${DISK}-part${PARTITION}"
echo -e "\n\n\n\n"
ls -l ${DISK}* 
echo -e "\nDo you see the disk and partition? (Hint: looking for partition ${PARTITION})\nIf not, Ctrl-C now and figure it out."
echo "Enter to continue."
read

pvcreate ${DISK_PART}
[[ $? -ne 0 ]] && { echo "Unable to pvcreate ${DISK_PART}.  It's probably not *completely* empty!"; exit 1; }

vgscan
vgs | grep -q "${VOLUMEGROUP}"
[[ $? -ne 0 ]] && { echo "Looking for ${VOLUMEGROUP} but didn't find it.  Something is rotten in the state of Denmark."; exit 1; }

ORIG_PV=$(pvs | awk -v VG="${VOLUMEGROUP}" '{ if( $0 ~ VG ) print $1 }')
: ${ORIG_PV:?"Can not find any PVs in ${VOLUMEGROUP}"}

vgextend ${VOLUMEGROUP} ${DISK_PART}
[[ $? -ne 0 ]] && { echo "Failed adding ${DISK_PART} to ${VOLUMEGROUP}"; exit 1; }

echo "Starting transfer from ${ORIG_PV} to ${DISK_PART}"
pvmove -i 10 ${ORIG_PV}
[[ $? -ne 0 ]] && { echo "Failed transfering data from ${ORIG_PV} to ${DISK_PART}"; exit 1; }

vgreduce ${VOLUMEGROUP} ${ORIG_PV}
[[ $? -ne 0 ]] && { echo "Failed removing ${ORIG_PV} from ${VOLUMEGROUP}"; exit 1; }

pvremove ${ORIG_PV}
[[ $? -ne 0 ]] && { echo "Failed wiping LVM headers from ${ORIG_PV}}"; exit 1; }

sync
echo "Done."

