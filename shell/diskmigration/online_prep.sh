#!/bin/bash

yum -y --nogpgcheck install kmod-hpvsa hpacucli

modprobe hpvsa
sleep 10

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

        hpacucli controller slot=0 add lk=3QCSS-X9WKV-4L4GL-D9R3V-L6V63
        
        hpacucli controller slot=0 physicaldrive all show
        [[ $? -eq 0 ]] || { echo "I didn't find any physical drives in this machine"; exit 1; }
        
        hpacucli controller slot=0 logicaldrive all show
        [[ $? -eq 0 ]] && { echo -e "There is already a logical drive configured.\nErroring on the side of safety and exiting."; exit 1; }
        
        hpacucli controller slot=0 array all show
        [[ $? -eq 0 ]] && { echo -e "There is already an array configured.\nErroring on the side of safety and exiting."; exit 1; }
        
        hpacucli controller slot=0 create type=ld drives=all raid=1 size=max
        [[ $? -eq 0 ]] || { echo "Failure creating the new logical drive"; exit 1; }

fi

grep -q "Intel Corporation C600/X79" <<< "${RAID_PCI}"
if [[ $? -eq 0 ]]
then
        FOUND_KNOWN_RAID=1
        PARTITION=2
        echo "Found nice hardware RAID controller"
        echo ""
        echo ""

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

DISK="$(hpacucli controller slot=0 logicaldrive 1 show | awk '{ if( $0 ~ /Disk Name:/ ) print $3 }')"
DISK_PART="${DISK}${PARTITION}"
echo -e "\n\n\n\nUsing the following disk:"
ls -l ${DISK}
[[ $? -eq 0 ]] || { echo "Can't find ${DISK}"; exit 1; }

echo -e "\n\nHoping I don't find ${DISK_PART}:"
ls -l ${DISK_PART}
[[ $? -eq 0 ]] && { echo "${DISK_PART} already exists"; exit 1; }

echo -e "\n\nIf ${DISK_PART} *was* found or you think something looks wrong Ctrl-C now or risk catastrophic data loss.\nOtherwise press Enter to continue."
read

PARTEDCMD="parted -s -m --align optimal ${DISK} unit s"
PARTED_PRINT_OUT="$(${PARTEDCMD} print)"

grep -q "unrecognised disk label" <<< "${PARTED_PRINT_OUT}"
if [[ $? -eq 0 ]]
then
	echo "No disk label present.  Making one."
	${PARTEDCMD} mklabel msdos
	[[ $? -eq 0 ]] || { echo "Disk label creation seems to have failed."; exit 1; }

	PARTED_PRINT_OUT="$(${PARTEDCMD} print)"
fi

PARTED_PART_LINE="$(awk -v PARTITION="${PARTITION}" 'BEGIN{ FS=":" }{ if( $1 == PARTITION ) print }' <<< "${PARTED_PRINT_OUT}")"
[[ ${PARTED_PART_LINE} == "" ]] || { echo "Expecting to create partition ${PARTITION}, but it seems to already exist."; exit 1; }

PART_START="0%"
PART_END="100%"

if [[ ${PARTITION} -gt 1 ]]
then
	PART_START="$(tail -n1 <<< "${PARTED_PRINT_OUT}" | awk 'BEGIN{ FS=":" }{ split($3,arr,"s"); print arr[1]+1 "s" }')"

	echo -e "\n\nAltering a disk that already has a partition.  Please verify the following looks ok."
	echo "Current partition table:"
	parted -s --align optimal ${DISK} unit s print
	echo -e "\nCreating partition #${PARTITION} starting at ${PART_START} and ending at ${PART_END}"
	echo -e "\n\nIf you think something looks wrong Ctrl-C now or risk catastrophic data loss.\nOtherwise press Enter to continue."
	read
fi

${PARTEDCMD} mkpart primary "${PART_START}" "${PART_END}"
MKPART_RET="$?"

${PARTEDCMD} set ${PARTITION} lvm on
SETLVM_RET="$?"

if [[ ${MKPART_RET} -ne 0 || ${SETLVM_RET} -ne 0 ]]
then
	echo -e "\n\n***Partition creation threw a non-zero exit code***\n\n"
	echo -e "If the only error you see is:\n\n\"Warning: WARNING: the kernel failed to re-read the partition table on ${DISK} (Device or resource busy)\"\n\nthen everything is ok.  Anything else needs closer examination.\n\n"
fi


echo -e "\n\nOnline prep script complete.  Here is the current partition table for ${DISK}:"
parted -s ${DISK} print

exit

