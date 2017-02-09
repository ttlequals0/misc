#!/bin/bash

nfsServer=192.168.101.117
dhcpPath="/mnt/nfs/dhcp"
dhcpFile="DHCP_Reservations_$(date "+%Y-%m-%d").csv"
dnsPath="/mnt/nfs/dns/"
dnsFile="dnsRecords_$(date "+%Y-%m-%d").csv"
ipaddr=$(ip addr |grep inet |grep 192 |awk {'print $2'} |sed 's/\/23//')
mac=$(ip addr |grep ether |awk {'print $2'} |tr ":" " " |sed 's/\s//g')
shortname=$(hostname |cut -d '.' -f 1)

##Generate ssh key amd add git server to known_hosts
if [ ! -d "/root/.ssh" ]; then
  mkdir ~/.ssh && chmod 700 ~/.ssh
fi

##ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
ssh-keyscan git.emmisolutions.com >> ~/.ssh/known_hosts && chmod 644 ~/.ssh/known_hosts 

#add testapp
echo "alias wartest\=\"curl https://$(hostname)/test/index.jsp\"" >> /root/.bashrc

##soft set hostname
hostname "$1"

##add hostname to hosts file 
echo "$ipaddr" "$(hostname)" "$shortname" >> /etc/hosts


##change hostname 
sed -i -e '/HOSTNAME/d' /etc/sysconfig/network
echo HOSTNAME="$(hostname)" >> /etc/sysconfig/network

##Update system
yum update -y

## Puppet
rpm -ivh http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm

##EPEL
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm

### Install Puppet
yum install puppet git telnet nfs-utils nfs-utils-lib -y

service rpcbind start

#DHCP reservation 
mkdir -p "$dhcpPath"
mount -o rw $nfsServer:/dhcp "$dhcpPath"
if [ ! -f "$dhcpPath"/"$dhcpFile" ]; then
touch "$dhcpPath"/"$dhcpFile"
echo IP,NAME,MAC >> "$dhcpPath"/"$dhcpFile"
fi
echo "$ipaddr","$(hostname)","$mac" >> "$dhcpPath"/"$dhcpFile"

#DNS Entry
mkdir -p "$dnsPath"
mount -o rw $nfsServer:/dns "$dnsPath"
if [ ! -f "$dnsPath"/"$dnsFile" ]; then
touch "$dnsPath"/"$dnsFile"
echo computer,IP >> "$dnsPath"/"$dnsFile"
fi
echo "$(hostname)","$ipaddr" >> "$dnsPath"/"$dnsFile"
#configure agent

sed -i '2i	     server = puppet.emmisolutions.com' /etc/puppet/puppet.conf


puppet agent --test
sleep 10 
puppet agent --test

#install xen tools.
cd "/root" || exit
wget --no-check-certificate  https://git.emmisolutions.com/devops/xentools6-5/repository/archive.zip
unzip ./archive.zip
cd ./xentools6-5.git || exit
echo y |./install.sh

#cleanup
cd "/root" || exit 
rm ./archive.zip
rm ./epel-release-6-8.noarch.rpm
rm ./remi-release-6.rpm
rm -rf ./xentools6-5.git
rm ./linuxSysprep.sh
rm ./updatedBootstrap.sh

#rboot
init 6

