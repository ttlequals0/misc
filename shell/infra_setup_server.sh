if [ -z $1 ]
then
    echo "Must supply an environment config file"
    exit -1;
fi
source $1

hostname `cat /etc/sysconfig/network | grep -i HOSTNAME | awk -F= '{print $2}'`
service ntpdate start
hwclock --systohc
service ntpd start
chkconfig ntpd on

mkdir -pv /var/www/html/tftpboot/pxelinux.cfg
spacewalk_pxemenu_create
sed -r -i 's/([[:space:]]*server_args[[:space:]]*=[[:space:]]*).*/\1-s \/var\/www\/html\/tftpboot/' /etc/xinetd.d/tftp

mkdir -pv /var/www/html/pxe

mkdir -pv /var/log/pxe
cat > /etc/rsyslog.d/pxe <<"EOF"
\$ModLoad imtcp
\$InputTCPServerRun 514
\$template PerHost,"/var/log/pxe/%fromhost-ip%.log"

if \$fromhost-ip startswith '$sitenet' then -?PerHost
& ~
EOF

cat > /etc/httpd/conf.d/pxe <<"EOF"
<Directory "$wwwroot/pxe">
    Options Indexes FollowSymLinks
    Order allow,deny
    Allow from all
</Directory>
EOF
cat >/etc/httpd/conf.d/tftpd <<"EOF"
<Directory "$wwwroot/tftpboot">
    Options Indexes FollowSymLinks
    Order allow,deny
    Allow from all
</Directory>
EOF

cat > /etc/init.d/2pcd <<'EOF'
# chkconfig: 345 20 80
# description: Manages srlabs recording service

service_name=srlabs_recorder
pid_file="/var/run/2pcd.pid"
run="/usr/sbin/2pcd --log syslog"
stop="killall 2pcd"

start()
{
    nohup $run > /dev/null 2>&1 &
    pid=$(pgrep 2pcd)
    [ -z "$pid" ] && echo "$pid" > "$pid_file" || ( echo "Start failed"; exit 1 )
    echo "Started $pid";
}

stop()
{
    echo "Stopping 2pcd"
    rm -f "$pid_file"
    $stop
}

status()
{
    pid=$(pgrep mdsub)

    if [ -e $pid_file ]
    then
        if [ -n "$pid" ]
        then
            echo "Service is running: $pid"
        else
            echo "Pid file exists but process not running"
        fi
    else
        echo "Service is stopped"
    fi
}

restart()
{
    stop
    sleep 1
    start
}


case "$1" in
    start)
        $1
        ;;
    stop)
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        restart
        ;;
    status)
        $1
        ;;
    *)
        echo "Usage: `basename $0` (start|stop|status|restart|reload)"
        exit 1
esac
exit $?
EOF
chmod +x /etc/init.d/2pcd
chkconfig 2pcd on

#Configure security
#if [ ! -f /tmp/kickstart ]
#then
#		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
#        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
#        iptables -A INPUT -p udp --dport 53 -j ACCEPT
#        iptables -A INPUT -p tcp --dport 69 -j ACCEPT
#        iptables -A INPUT -p udp --dport 69 -j ACCEPT
#        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
#		iptables -A INPUT -p tcp --dport 389 -j ACCEPT
#        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
#        iptables -A INPUT -p tcp --dport 5222 -j ACCEPT
#		iptables -A INPUT -p tcp --dport 9830 -j ACCEPT
#        iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
#        service iptables save
#        service iptables restart
#else
#        cp /etc/sysconfig/iptables{,.tmp}
#        cat /etc/sysconfig/iptables.tmp | head -n -4 > /etc/sysconfig/iptables
#        rm -f /etc/sysconfig/iptables.tmp;
#        sed -i 's/OUTPUT ACCEPT \[.*\]/OUTPUT ACCEPT [2:296]/' /etc/sysconfig/iptables
#        cat >> /etc/sysconfig/iptables <<'EOF'
#*filter
#-A INPUT -p tcp --dport 22 -j ACCEPT
#-A INPUT -p tcp --dport 53 -j ACCEPT
#-A INPUT -p udp --dport 53 -j ACCEPT
#-A INPUT -p tcp --dport 69 -j ACCEPT
#-A INPUT -p udp --dport 69 -j ACCEPT
#-A INPUT -p tcp --dport 80 -j ACCEPT
#-A INPUT -p tcp --dport 443 -j ACCEPT
#-A INPUT -p tcp --dport 5222 -j ACCEPT
#-A INPUT -j REJECT --reject-with icmp-host-prohibited
#-A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
#-A FORWARD -j REJECT --reject-with icmp-host-prohibited
#COMMIT
#EOF
#fi

ssh-keygen -f /root/.ssh/id_rsa -N '' -b 2048

if [ ! -z $yum_proxy ] && [ ! -f /tmp/kickstart ]
then
    echo "proxy=$yum_proxy" >> /etc/yum.conf
fi

for i in {all,default,$(ifconfig | grep encap:Ethernet | awk '{print $1}')} #'
do
    sysctl net.ipv4.conf.$i.rp_filter=0;
    cat /etc/sysctl.conf | grep "$i.rp_filter=0" 2>&1 > /dev/null;
    if [ $? -eq 1 ]
    then
        echo "net.ipv4.conf.$i.rp_filter=0" >> /etc/sysctl.conf
    fi
done

#Setup LLDP
/sbin/service lldpad start
for i in $(ifconfig | grep encap:Ethernet | awk '{print $1}')
do
    lldptool -L -i $i adminStatus=rxtx
    lldptool -T -V portDesc -i $i enableTx=yes
    lldptool -T -V sysName -i $i enableTx=yes
done


#Copy resources over from ISO
cdrom="/dev/`ls /dev | grep cdrom | tail -n 1`"
mkdir -p /var/www/html/repo
mkdir /mnt/install
mount -o loop $cdrom /mnt/install
cp -fv /mnt/install/isolinux/splash.png /var/www/html/tftpboot
cp -fv /mnt/install/isolinux/issue /etc/spacewalk/
cp -Rf /mnt/install/custom_rpms/* /var/www/html/repo
umount /mnt/install
rmdir /mnt/install
createrepo /var/www/html/repo
cat > /etc/httpd/conf.d/repo <<'EOF'
<Directory>
        Options Indexes MultiViews
        AllowOverride None
        Order allow,deny
        Allow from all
</Directory>
EOF

sed -i "\$ a\relayhost=$smtp_relay" /etc/postfix/main.cf

updatedb
