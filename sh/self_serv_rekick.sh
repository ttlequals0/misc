function ttdns {
       			unset OCTET2 OCTET3 OCTET4	
				HOST=$(echo "$1" | tr '[:upper:]' '[:lower:]')
				OCTET1=10
				if [[ $HOST == m-* ]] ; then
					HOSTDC=${HOST:0:4}
				else
					HOSTDC=${HOST:0:2}
				fi

				case $HOSTDC in
					[Aa][Rr]) OCTET2=102 ;;
					[Cc][Hh]) OCTET2=111 ;;
					[Ff][Rr]) OCTET2=127 ;;
					[Ss][Yy]) OCTET2=144 ;;
					[Ss][Gg]) OCTET2=143 ;;
					[Nn][Yy]) OCTET2=113 ;;
					[Ll][Nn]) OCTET2=126 ;;
					[Hh][Kk]) OCTET2=145 ;;
					[Tt][Kk]) OCTET2=142 ;;
					[Mm]-[Aa][Rr]) OCTET2=204 ;;
					[Mm]-[Ff][Rr]) OCTET2=206 ;;	
					[Mm]-[Cc][Hh]) OCTET2=205 ;;																	
				esac
				if [[ $HOST == m-* ]] ; then
					OCTET3=${HOST:4:1}
				else
					OCTET3=${HOST:2:1}
				fi
				
				if [[ $HOST == m-* ]] ; then
					if [[ $HOST == m-*vmh* ]] || [[ $HOST == M-*VMH* ]]; then
						OCTET4=${HOST:8:5}	
					elif [[ $HOST == m-*vm* ]] || [[ $HOST == M-*VM* ]]; then
						OCTET4=${HOST:7:5}
					elif [[ $HOST == m-*srv* ]] || [[ $HOST == M-*SRV* ]]; then
						OCTET4=${HOST:8:5}																	
					fi
				else	
					if [[ $HOST == *srv* ]] || [[ $HOST == *SRV* ]]; then
						OCTET4=${HOST:6:3}
					elif [[ $HOST == *vmh* ]] || [[ $HOST == *VMH* ]]; then
						OCTET4=${HOST:6:3}
					elif [[ $HOST == *vm* ]] || [[ $HOST == *VM* ]]; then
						OCTET4=${HOST:5:3}
					fi
				fi	

			IP="$OCTET1.$OCTET2.$OCTET3.$OCTET4"
			echo $IP
} 

bail () {
	echo -e "Error: $1"
  	exit ${1:="1"}
}


ssh_options=" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=30 -t -t -i $(pwd)/Spacewalk/script/id_rsa"

while getopts ":H:v:" opt; do
  case $opt in
        H) Hflag="defined"; hostip=$(ttdns $OPTARG) ;;
        v) vflag="defined"; CENTOS_VERSION="$OPTARG" ;;
    	\?) echo "Invalid option: -$OPTARG" >&2 ; bail 1 ;;
    	:)  echo "Option -$OPTARG requires an argument." >&2 ; bail 2      
  esac
done

echo "$hostip"
[[ $hostip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || bail 3
echo "$hostip"
site=$(echo $hostip | awk -F "."  '{print $2}')

if [[ $site == 204 ]] ; then pxeip="10.$site.0.29"
elif [[ $site == 205 ]] ; then pxeip="10.$site.0.28"
elif [[ $site == 206 ]] ; then pxeip="10.$site.0.28"
elif [[ $site == 102 ]] ; then pxeip="10.$site.0.30"
elif [[ $site == 111 ]] ; then pxeip="10.$site.0.30"
elif [[ $site == 113 ]] ; then pxeip="10.$site.0.30"
elif [[ $site == 127 ]] ; then pxeip="10.$site.0.30"
elif [[ $site == 144 ]] ; then pxeip="10.$site.0.28"
elif [[ $site == 143 ]] ; then pxeip="10.$site.0.28"; fi


if [[ $CENTOS_VERSION == "6.4" ]] ; then 
	CONFIG_FILE="phy.cfg"
	getinitrd=" wget -P /boot/ http://$pxeip/tftpboot/pxelinux.cfg/files/initrd.working &&"
	getkernel=" wget -P /boot/ http://$pxeip/pxe/centos/6.4/images/pxeboot/vmlinuz &&"
	initrdname="initrd.working"
elif [[ $CENTOS_VERSION == "6.7" ]] ; then 
	CONFIG_FILE="phy3.cfg" 
	getinitrd=" wget -P /boot/ http://$pxeip/tftpboot/EFI/BOOT/files/6.7/initrd-sfc8k.img &&"
	getkernel=" wget -P /boot/ http://$pxeip/tftpboot/EFI/BOOT/files/6.7/vmlinuz &&"
	initrdname="initrd-sfc8k.img"
fi

backupgrub=" cp /boot/grub/grub.conf{,.bak} && "
updategrub="grubby --add-kernel=/boot/vmlinuz --args=\"ks=http://$pxeip/pxe/centos/$CONFIG_FILE ksdevice=eth0 blacklist=ahci\" --initrd=/boot/$initrdname --make-default --title=CentOS_Linux_PXE_install &&"
reboot="init 6"

chmod 600 "$(pwd)/Spacewalk/script/id_rsa"
ssh $ssh_options  "root"@$hostip "$getinitrd $getkernel $backupgrub $updategrub $reboot" || bail 4

unset count
while [ "$status" != "0" ] 
    do 
	   echo  "$hostip is still being re-kicked..."
	   sleep 30
	   ssh-keyscan $hostip 2>&1 | grep -v "^$" > /dev/null
	   status=$?
	   =$((count++)) &>/dev/null
	   if [[ $count == "100" ]] ; then bail 3; fi
done
sleep 30
nettest=$(ssh $ssh_options  "root"@$hostip "if /root/network_health |grep 'vlan' |grep -iq 'not' ;then echo 1; else echo 0 ; fi" 2>/dev/null)
echo $nettest
export result=$nettest
[[ $result =~ 0 ]] || bail 5
    echo "Re-kick completed successfully."
    exit 0 
