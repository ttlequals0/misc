#KS.cfg maker
for i in $(seq 184); do cp fr2vm183-ks.cfg fr2vm$i-ks.cfg && sed -i -e "s/fr2vm183/fr2vm$i/" fr2vm$i-ks.cfg && sed -i -e "s/octet\=183/octet\=$i/"  fr2vm$i-ks.cfg; done
#export VDS Powershell
Get-VDSwitch -Name *  | Foreach { Export-VDSwitch -VDSwitch $_ -Description “Backup of $($_.Name) VDS” -Destination “c:\VDS\Legacy\$($_.Datacenter.Name)-$($_.Name).Zip” -Force}
 #mail
 echo "some trival message here" | mailx -s "Unmap M-AR complete" dkrachtus@trade.tt
 #remove VHMhosts
 Get-VMHost -Location "New York MOVED TO TTN ET-CH-VM-3.ttnet.local"|Remove-VMHost -confirm:$false
 #Eject all CDS
 Get-VM -Name *m-ar* | Where-Object  {$_.PowerState -eq "PoweredOn"} | Get-CDDrive | Set-CDDrive -Connected $false -Confirm:$false 

 cp fr2vm172-ks.cfg fr2vm173-ks.cfg && sed -i -e "s/fr2vm172/fr2vm173/" fr2vm173-ks.cfg && sed -i -e "s/octet\=172/octet\=173/"  fr2vm173-ks.cfg
#store vcenter creds
New-VICredentialStoreItem -Host 172.17.250.175 -User administrator -Password TTN
#VIB audit
Get-VMHost -name * | %{  $esxcli = Get-EsxCli -VMHost $_ ; Write-Host "$_" ; $esxcli.software.vib.list() | Where { $_.Name -like "hp-ams"} | Select Version | Where {$_.Version -NotLike "550.10*"}  }
Get-VMHost -name * | %{  $esxcli = Get-EsxCli -VMHost $_ ; Write-Host "$_"  ; Write-Host  ; $esxcli.software.vib.list() | Where { $_.Name -like "hp-ams"} }
#76-persistent-net create
for i in $(cat ny_servers);do ssh -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=3 -t -t  $i "hostname && sudo cp /etc/udev/rules.d/70-persistent-net.rules  /etc/udev/rules.d/76-persistent-net.rules"; done
#76-persistent-net test
for i in $(cat fr_servers);do ssh $i "hostname && stat -c %a /etc/udev/rules.d/76-persistent-net.rules"; done

#add module path powershellposh-ssh
$env:PSModulePath = $env:PSModulePath + ";C:\Users\Administrator.MTN\Documents\WindowsPowerShell\Modules"

#SCP powershell
$username = "runner"
$password = ConvertTo-SecureString "password" -AsPlainText -Force
Set-SCPFile -LocalFile C:\Users\dkrachtus\Desktop\output.txt -RemoteFile "/tmp/output" -ComputerName 10.192.2.38 -Credential (Get-Credential dkrachtus)
$cred = new-object -typename System.Management.Automation.PSCredential `
         -argumentlist $username, $password


Set-SCPFile -LocalFile "C:\Users\dkrachtus\Desktop\output.txt" -RemotePath "/tmp/op1" -ComputerName 10.192.2.138 -Credential  $Cred -KeyFile C:\Users\dkrachtus\id_rsa -ConnectionTimeOut 33 -verbose

#convert hostname and find missing 76 file
ch_names=$(awk '{print $1}' ./ch_all) && for i in $(echo $ch_names); do parse echo $i >> ch_ip ;done && pssh -h ch_ip --inline-stdout -A -O "StrictHostKeyChecking=no"  "hostname && stat -c %a /etc/udev/rules.d/76-persistent-net.rules" |grep -i "Exited with error code 1" |awk '{print $4}' |sort

curl -s http://10.192.2.138/vmmapping/mapping.php | grep -i "poweredon" |grep -oP '[A-z]{2}\d[VMvm]{2}\d{1,3}' |grep "ny" |sort >> tmp1 && for i in $(cat tmp1); do ttdns echo $i  >> tmp2; done && pssh -h tmp2 --inline-stdout -A -O "StrictHostKeyChecking=no"  "hostname touch /tmp/test" |grep -i "Exited with error code 1" |awk '{print $4}' |sort  |tee -a broke && rm tmp1 tmp2

#look for jacked up 70 file
pssh -h broke --inline-stdout -A -x "-o StrictHostKeyChecking=no"  "hostname && grep 'NAME=\"eth'  /etc/udev/rules.d/70-persistent-net.rules"
#fix 76 file 
pssh -h broke --inline-stdout -A -x "-o StrictHostKeyChecking=no -t -t "  "hostname && sudo cp /etc/udev/rules.d/70-persistent-net.rules  /etc/udev/rules.d/76-persistent-net.rules"

#Grep go/VMH
curl -s http://10.195.2.138/vmmapping/mapping.php |grep -oP '[A-z]{2}\d[VMvm|SRVsrv|CAPcap]{2,3}\d{1,3}' |grep sg |sort
curl -s http://10.192.2.138/vmmapping/mapping.php |grep -oP '[A-z]{1,4}\-[A-z]{1,3}\-\w+[^esx|3PAR]\-\d+'
curl -s http://10.195.2.138/vmmapping/mapping.php |grep -oP '[A-z]{2}\d[VMvm]{2}\d{1,3}'  | while read i   ;do  ttdns echo $i ; done
#connect to virt-manager
virt-manager -c qemu+ssh://root@10.206.0.42/system?socket=/var/run/libvirt/libvirt-sock

 knife ssh "name:*cap*" "cat /proc/cpuinfo | grep process | wc -l | grep 40"  --attribute ipaddress --config 

#add ssh key 
if [ ! -d ~/.ssh ]; then mkdir ~/.ssh ; fi && chmod 700 ~/.ssh && echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyqySDh7gyUVMzkBPVmEursQmU2DSlVp81jGX8RnKAHLzZVcJnZUcH/TzmSShNL9MqxHmigY/tOplk+slvuaMvLaDWlzuiG4XGrrjw+2dXrU9ELXn+NNxYIjj8m2II6JR6YUl9BkfnFzKNUwEYiiuL1O2ya9fw2yjYCgij2f/VXGA9yH6LSlBr23CeSr76k0tePNkVakjBYWrLWqviZ1ZnF7WozwDaBLJwL2Z48p4kg6H2/HN8EkW6bIXM8T6eBNOqNnpiOWtyrMIpUyWpf6LAeyRuZ7DUQ3WYkDL7hdRzPRHbExGpWpw1l8wPMXO+mMmTgdvYpTIITGUeh/sMT/jD dominick.krachtus@tradingtechnologies.com" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
##esxi host config##
#enable ssh 
Get-VMHost 10.111.0.74 | Foreach {Start-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) ;$_| Get-AdvancedSetting UserVars.SuppressShellWarning | Set-AdvancedSetting -Value 1 -Confirm:$false ; $_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} |Set-VMHostService -Policy "on"}
#set NTP
$esx = "10.204*" ; Add-VmHostNtpServer -VMHost $esx -NtpServer 0.centos.pool.ntp.org ;add-VmHostNtpServer -VMHost $esx -NtpServer 1.centos.pool.ntp.org ; Add-VmHostNtpServer -VMHost $esx -NtpServer 2.centos.pool.ntp.org ; Add-VmHostNtpServer -VMHost $esx -NtpServer 3.centos.pool.ntp.org ; Get-VMHostFirewallException -VMHost $esx | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true ; Get-VmHostService -VMHost $esx | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService ; Get-VmHostService -VMHost $esx | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
#enable syslog
get-vmhost 10.204*| Set-VMHostAdvancedConfiguration -NameValue @{'Config.HostAgent.log.level'='info';'Vpx.Vpxa.config.log.level'='info';'Syslog.global.logHost'='udp://10.204.2.103:514'}
get-vmhost 10.204* | Get-VMHostFirewallException |?{$_.Name -eq 'syslog'} | Set-VMHostFirewallException -Enabled:$true

#print multiline on same line
awk 'NR%2{printf $0" ";next;}1'

#set rp_filters

for i in {all,default,$(ifconfig | grep encap:Ethernet |  awk '{print $1}')} ; do  sudo sysctl net.ipv4.conf.$i.rp_filter=0;  cat /etc/sysctl.conf | grep "$i.rp_filter=0" 2>&1 > /dev/null;if [ $? -eq 1 ];   then sudo  echo "net.ipv4.conf.$i.rp_filter=0" |sudo  tee -a /etc/sysctl.conf ; fi ; done && sudo sysctl -p

#bring up all interfaces
for i in $(ifconfig -a | sed 's/[ \t].*//;/^\(lo\|\)$/d' |sed 's/://') ; do ifconfig $i up; done

#Add VLAN 
sudo wget -q http://10.127.0.30/bootstrap/querySN -O /tmp/querySN && sudo wget -q http://10.127.0.30/bootstrap/addNIC -O /tmp/addNIC  && sudo chmod +x /tmp/querySN && sudo chmod +x /tmp/addNIC && sudo /tmp/querySN --action setexchange --vlan VLAN738

#view lldp info 
tcpdump -nn -v -i vlan723 -s 1500 -c 1 '(ether[12:2]=0x88cc or ether[20:2]=0x2000)'

#vmware find delta of missed packets
 while : ; do count1=$(esxcli network nic stats get -n vmnic4 | grep "missed errors" |cut -d " " -f 7) ; sleep 60 ;count2=$(esxcli network nic stats get -n vmnic4 | grep "missed errors" |cut -d " " -f 7);  $((min++)) &>/dev/null ; echo "Minute: $min Receive missed errors Delta: $(($count2-$count1))" ; done
#linux find delta of missed packets
 while : ; do count1=$(sudo ethtool -S eth1 |grep "rx_dropped" | awk {'print $2}') ; sleep 60 ;count2=$(sudo ethtool -S eth1 |grep "rx_dropped" | awk {'print $2}');  $((min++)) &>/dev/null ; echo "Minute: $min Receive missed errors Delta: $(($count2-$count1))" ; done
#linux find delta of gaps logged
while : ; do count1=$(grep -i "gap" /var/log/debesys/md_client_edgeserver.log |wc -l) ; sleep 60 ;count2=$(grep -i "gap" /var/log/debesys/md_client_edgeserver.log |wc -l);  $((min++)) &>/dev/null ; echo "$(date +%FT%T): Minute: $min: Gaps logged Delta: $(($count2-$count1))" ; done

#subnet generator
nmap -sL 10.206.0.1/22 | grep "Nmap scan report" | awk '{print $NF}'
#squid config 
ipaddr=$( /sbin/ip addr |grep eth0 |grep inet |grep 10 |awk '{print $2}' |sed 's/\/22//') && wrongip=$(echo 10.102.0.30 |sed 's/\./\\\./g') && rightip=$(echo "$ipaddr" |sed 's/\./\\\./g') && sed -i -e "s/$wrongip/$rightip/" /etc/squid/squid.conf && service httpd restart && service squid restart

#rhn fix
rhnreg_ks --activationkey 1-debsrv-001 --server http://10.111.0.28/XMLRPC --force
#AWS DNS check
time pssh -h allawsips  --inline-stdout -A -x "-o StrictHostKeyChecking=no -o ConnectTimeout=1"  "if grep -iq 'chef' /etc/resolv.conf ;then echo bad ; fi"  |tee -a awsresults
#awk math
cat ~/gapdetect.$(date +%F).log | awk '{ sum+=$7} END {print sum}'
#SNAMP enable
pssh -h snmpfix --inline-stdout -A -l ttnet  -x "-o StrictHostKeyChecking=no -t -t -C "  "set /map1/snmp1 readcom1=\"ttcommRO\""
for i  in $(cat arilo) ; do  snmpwalk -v1 -c ttcommRO $i .1.3.6.1.4.1.232.6.2.9.3.1.7.0.1   2>/dev/null ; done
#screen hack 
sudo -u pnano screen -list
 sudo -u pnano  script -q -c 'screen -r 20106.pts-0.ar2vm116' /dev/null

##ttknife stuff
#list all nodes 
ttknife -C ~/.chef/knife.external.rb node list
knife search node "chef_environment:ext-prod-* AND name:*vm*" --config ~/.chef/knife.external.rb

#ssh tunnel
 ssh -L 19999:localhost:19999 root@10.200.203.41 -f -N 

#List count of Established TCP connections by IP address
netstat -npt | grep <port> | grep ESTABLISHED | awk '{print $5}' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | cut -d: -f1 | sort | uniq -c | sort -nr | head
#pssh options
pssh -h capips --inline-stdout -A -l dkrachtus  -x " -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -t -t -C "

#GWClite
\\ttnet-ch-nas-fs.ttnet.local\installables\ttinstall\gwclite\gwclite.exe user=dkrachtus type=xtr action=full priip=118.20.1.55
\\ttnet-ch-nas-fs\installables\ttinstall\gwclite\gwclite.exe user=dkrachtus type=fix action=validate
#gwclite add nic
\\ttnet-uk-nas-fs\installables\ttinstall\gwclite\gwclite.exe user=dkrachtus action=addint type=mef secip=10.128.30.156 secnet=255.255.255.192 secnetname=MEF  VMNetName="MEFF Servers" 
#Reserver IP
\\ttnet-uk-nas-fs\installables\ttinstall\gwclite\gwclite.exe user=dkrachtus action=findip reserveip=10.128.30.156
#Bulk add esxi hosts
Get-Content dehosts.txt | Foreach-Object { Add-VMHost $_ -Location (Get-Datacenter Frankfurt) -User root -Password <pass> -RunAsync -force:$true}
#apply host profile
Get-Content dehosts.txt | Foreach-Object { Apply-VMHostProfile -Profile TTNET_FR_SL230 -Entity $_ -RunAsync -Confirm:$false }
#reboot host
Get-Content ch151.txt | Foreach-Object  {  Restart-VMHost $_ -RunAsync -Confirm:$false }
#Grab power usage
for i in $(seq 31 70); do host="10.143.8.$i" ; rawwatts=$(snmpwalk -v1 -c ttcommRO 10.143.8.$i .1.3.6.1.4.1.232.6.2.9.3.1.7.0.1 2>/dev/null); watts=$(echo $rawwatts | awk -F ":" '{print $4}'); echo  "$host  $watts Watts" ; done
 #find missing snmp data
 awk '($2 == "Watts") || ($1 ~/^#/)' missing
 #p2v csv 
  awk '{ split($1, a, "-"); print $1","a[2]" Servers"}' uk5 | tr '[:lower:]' '[:upper:]' |sed 's/ERVERS/ervers/' >uk5.csv
  #p2v get ipaddress
curl -O -s  http://10.195.2.138/vmmapping/prod_ttnet.csv ;while read "vm" ; do grep -iw  "$vm" prod_ttnet.csv |awk -F "," -v var="$vm" '{if ( $2 == "" ) $2 = "--";print var","$2}' |sed 's/\"//g' |tr "[:lower:]" "[:upper:]" ; done < p2v |awk -F "," '{print $2}'
#get windows serial number
wmic bios get serialnumber