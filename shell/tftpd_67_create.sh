### GRAB SYNTAX ####
CITY=$1
SS="30"
if [[ $CITY == "" ]]; then
	echo "You must specify the city code (e.g. 204)"
	exit
fi
if [[ $CITY == "204" ]]; then
	SS="29"
elif [[ $CITY == "143" ]] || [[ $CITY == "144" ]] || [[ $CITY == "204" ]] || [[ $CITY == "205" ]] || [[ $CITY == "206" ]]; then
	SS="28"
fi

echo "Chose city $CITY with $SS"

cat > /tftpboot/pxelinux.cfg/default << EOF
MENU TITLE System Integration PXE
MENU INCLUDE pxelinux.cfg/graphics.conf
MENU BACKGROUND splash.png
PROMPT 0
TIMEOUT 100
ONTIMEOUT local
DEFAULT vesamenu.c32
LABEL VM
        MENU LABEL Virtual Machine
        KERNEL vesamenu.c32
        APPEND pxelinux.cfg/VM/default
LABEL BM
        MENU LABEL Bare Metal
        KERNEL vesamenu.c32
        APPEND pxelinux.cfg/PHY/default
LABEL CAP
        MENU LABEL CAP
        KERNEL vesamenu.c32
        APPEND pxelinux.cfg/CAP/default

MENU SEPARATOR
LABEL local
        MENU LABEL Boot from local disk
        LOCALBOOT 0
MENU END
EOF




cat > /tftpboot/pxelinux.cfg/PHY/default << EOF
MENU TITLE System Integration PXE
MENU INCLUDE pxelinux.cfg/graphics.conf
MENU BACKGROUND ../splash.png
PROMPT 0
LABEL BM CentOS 6.4
        MENU LABEL Deploy Bare Metal CentOS 6.4
        KERNEL pxelinux.cfg/files/vmlinuz
        INITRD pxelinux.cfg/files/initrd.working ks=http://10.$CITY.0.$SS/pxe/centos/phy.cfg
        APPEND ksdevice=bootif sshd loglevel=debug blacklist=ahci
        IPAPPEND 2
LABEL noEFI
        MENU LABEL Deploy Bare Metal CentOS 6.7 non-EFI host
        KERNEL EFI/BOOT/files/6.7/vmlinuz
        INITRD EFI/BOOT/files/6.7/initrd-sfc8k.img ks=http://10.$CITY.0.$SS/pxe/centos/phy3.cfg
        APPEND ksdevice=bootif sshd loglevel=debug blacklist=ahci
        IPAPPEND 2
LABEL Back
        MENU LABEL Back
        KERNEL vesamenu.c32
        APPEND pxelinux.cfg/default

MENU END
EOF


cat > /tftpboot/pxelinux.cfg/VM/default << EOF
MENU TITLE System Integration PXE
MENU INCLUDE pxelinux.cfg/graphics.conf
MENU BACKGROUND ../splash.png
PROMPT 0

LABEL VM 6.4
        MENU LABEL Deploy Virtual Machine CentOS 6.4
        KERNEL pxelinux.cfg/files/vmlinuz
        INITRD pxelinux.cfg/files/initrd.working ks=http://10.$CITY.0.$SS/pxe/centos/vm.cfg
        APPEND ksdevice=bootif sshd syslog=10.$CITY.0.$SS:514 loglevel=debug
        IPAPPEND 2
LABEL VM 6.7
        MENU LABEL Deploy Virtual Machine CentOS 6.7
        KERNEL EFI/BOOT/files/6.7/vmlinuz
        INITRD EFI/BOOT/files/6.7/initrd-sfc8k.img ks=http://10.$CITY.0.$SS/pxe/centos/vm2.cfg
        APPEND ksdevice=bootif sshd loglevel=debug blacklist=ahci
        IPAPPEND 2
LABEL Back
        MENU LABEL Back
        KERNEL vesamenu.c32
        APPEND pxelinux.cfg/default

MENU END
EOF





cat > /tftpboot/pxelinux.cfg/CAP/default << EOF
MENU TITLE System Integration PXE
MENU INCLUDE pxelinux.cfg/graphics.conf
MENU BACKGROUND ../splash.png
PROMPT 0
LABEL BM CentOS 6.4
        MENU LABEL Deploy Bare Metal CAP CentOS 6.4
        KERNEL pxelinux.cfg/files/vmlinuz
        INITRD pxelinux.cfg/files/initrd.working ks=http://10.$CITY.0.$SS/pxe/centos/cap.cfg
        APPEND ksdevice=bootif sshd loglevel=debug blacklist=ahci
        IPAPPEND 2
LABEL noEFI
        MENU LABEL Deploy Bare Metal CAP CentOS 6.7 non-EFI host
        KERNEL KERNEL EFI/BOOT/files/6.7/vmlinuz
        INITRD EFI/BOOT/files/6.7/initrd-sfc8k.img ks=http://10.$CITY.0.$SS/pxe/centos/cap2.cfg
        APPEND ksdevice=bootif sshd loglevel=debug blacklist=ahci
        IPAPPEND 2
LABEL Back
        MENU LABEL Back
        KERNEL vesamenu.c32
        APPEND pxelinux.cfg/default

MENU END
EOF


###### COPY FILES   ######
yes | cp -f ../drivers/*.dd /pxe/centos/drivers/
yes | cp -f ../tftpd/splash.png /tftpboot/

### CREATE EFI #####
mkdir -p /tftpboot/EFI/BOOT/files/6.7/

yes | cp -f ../tftpd/BOOTX64.efi /tftpboot/EFI/BOOT/
yes | cp -f ../tftpd/initrd-sfc8k.img /tftpboot/EFI/BOOT/files/6.7/
yes | cp -f ../tftpd/vmlinuz /tftpboot/EFI/BOOT/files/6.7/


##### CREATE EFIDEFAUT ######
cat > /tftpboot/EFI/BOOT/efidefault << EOF
debug --graphics
default=0
#splashimage=EFI/splash.xpm.gz
timeout 60000
# hiddenmenu

title Deploy Bare Metal CentOS 6.7
    root (nd)
    insmod gzio
    insmod part_gpt
    insmod ext2
    insmod efi_gop
    insmod efi_uga
    kernel /files/6.7/vmlinuz ks=http://10.$CITY.0.$SS/pxe/centos/phy2.cfg ksdevice=link sshd loglevel=debug blacklist=ahci
    initrd /files/6.7/initrd-sfc8k.img

title Deploy CAP Device CentOS 6.7
    root (nd)
    insmod gzio
    insmod part_gpt
    insmod ext2
    insmod efi_gop
    insmod efi_uga
    kernel /files/6.7/vmlinuz ks=http://10.$CITY.0.$SS/pxe/centos/cap3.cfg ksdevice=link sshd loglevel=debug blacklist=ahci
    initrd /files/6.7/initrd-sfc8k.img

title Deploy VM CentOS 6.7
    root (nd)
    insmod gzio
    insmod part_gpt
    insmod ext2
    insmod efi_gop
    insmod efi_uga
    kernel /files/6.7/vmlinuz ks=http://10.$CITY.0.$SS/pxe/centos/vm2.cfg ksdevice=link sshd loglevel=debug
    initrd /files/6.7/initrd-sfc8k.img
EOF


#### MODIFY DHCPD ######
if [[ $CITY = "111" ]]; then
	NSERVERS="10.111.2.70,,10.111.2.71,10.102.2.54"
fi
if [[ $CITY = "102" ]]; then
	NSERVERS="10.102.2.54,10.102.2.55,10.111.2.70"
fi
if [[ $CITY = "113" ]]; then
	NSERVERS="10.113.2.190,10.13.2.191,10.111.2.70"
fi
if [[ $CITY = "127" ]]; then
	NSERVERS="10.127.2.85,10.127.2.86,10.113.2.190"
fi
if [[ $CITY = "143" ]]; then
	NSERVERS="10.143.2.61,10.143.2.62,10.144.2.113"
fi
if [[ $CITY = "144" ]]; then
	NSERVERS="10.144.2.113,10.144.2.114,10.143.2.61"
fi

if [[ $NSERVERS = "" ]]; then
	NSERVERS="8.8.8.8,4.4.8.8"
fi

cat > /etc/dhcp/dhcpd.conf << EOF
# /etc/dhcpd.conf

ddns-domainname "pi.domain";
ddns-update-style interim;
update-static-leases on;
allow booting;
allow bootp;
authoritative;

option arch code 93 = unsigned integer 16; # RFC4578
subnet 10.$CITY.0.0 netmask 255.255.252.0 {
        option routers                  10.$CITY.0.1;
        option subnet-mask              255.255.252.0;
        option broadcast-address        10.$CITY.0.255;
        option domain-name-servers      $NSERVERS;
        range dynamic-bootp             10.$CITY.3.200 10.$CITY.3.254;
        default-lease-time              900;
        max-lease-time                  1800;
        next-server                     10.$CITY.0.$SS;
        class "pxe-clients" {
                match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
                if option arch = 00:07 {
                        filename "EFI/BOOT/BOOTX64.efi";
                } else {
                        filename "pxelinux.0";
                }
        }
}

EOF

service dhcpd restart
service xinetd restart
