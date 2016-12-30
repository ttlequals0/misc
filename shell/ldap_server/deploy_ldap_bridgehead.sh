#!/bin/bash
set -e
if [ -z "$1" ]
then
    echo "Must supply an environment config file"
    exit -1;
fi
source $1

instance_id=$(hostname -i | awk -F. '{print $2$4}')
if [ -z $instance_id ]; then
	logger "$0: could not parse instance_id from hostname"
	exit -1
elif [ $instance_id -gt 65535 ]; then
	logger "$0: instance_id $instance_id is invalid, trying alternate pattern"
	instance_id=$(hostname -i | awk -F. '{print $3$4}')
	if [ $instance_id -gt 65535 ]; then
		logger "$0: alternate instance_id $instance_id is invalid"
		exit -1
	fi
fi
logger "$0: using instance_id $instance_id"

rm -fv /etc/httpd/conf.d/nss.conf || echo "nss.conf not present"

#set recommended system limits if not already configured
nofile="*               -       nofile          8192"
ulimit -n 8192
grep "^$nofile$" /etc/security/limits.conf >/dev/null || echo "$nofile" >> /etc/security/limits.conf

function update_sysctl {
	echo "" >> /etc/sysctl.conf
	echo "# Override the default 7200 second keepalive time for optimal performance with port389." >> /etc/sysctl.conf
	echo "$tcp_keepalive" >> /etc/sysctl.conf
}
tcp_keepalive="net.ipv4.tcp_keepalive_time = 600"
sysctl -w net.ipv4.tcp_keepalive_time=600 >/dev/null
grep "^$tcp_keepalive$" /etc/sysctl.conf >/dev/null || update_sysctl

#create the system-wide cacerts config
mkdir $cacertdir || echo "cacerts directory $cacertdir already exists"
cat > /etc/openldap/ldap.conf << EOF
TLS_cacertdir   $cacertdir
TLS_REQCERT     NEVER
EOF

#create the ldif files for replication config
repl_mgr_ldif="/tmp/repl_mgr.ldif"
cat <<EOF > $repl_mgr_ldif
dn: $ds_repl_dn
objectClass: inetorgperson
objectClass: person
objectClass: top
cn: replication manager
sn: RM
userPassword: $ds_repl_pass
EOF

changelog_ldif="/tmp/changelog.ldif"
cat <<EOF > $changelog_ldif
dn: cn=changelog5,cn=config
changetype: add
objectClass: top
objectClass: extensibleObject
cn: changelog5
nsslapd-changelogdir: /var/lib/dirsrv/slapd-$HOSTNAME/changelogdb
nsslapd-changelogmaxage: 30d
EOF

#create the inf for the unattended dirsrv setup
inf=/tmp/ds-setup.inf
cat <<EOF > $inf
[General]
AdminDomain = $(hostname -d)
ConfigDirectoryAdminID = admin
ConfigDirectoryAdminPwd = $ds_mgr_pass
FullMachineName = $(hostname -f)
SuiteSpotGroup = nobody
SuiteSpotUserID = nobody
[slapd]
RootDN = cn=Directory Manager
RootDNPwd = $ds_mgr_pass
ServerIdentifier = $HOSTNAME
ServerPort = 389
SlapdConfigForMC = no
UseExistingMC = no
Suffix = $ds_ldap_dc
ConfigFile = $repl_mgr_ldif
ConfigFile = $changelog_ldif
EOF

#run the ds setup
setup-ds.pl --silent --file=$inf
chkconfig dirsrv on

#add the supplier config
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=replica,cn="$ds_ldap_dc",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replica
objectclass: extensibleObject
cn: replica
nsds5replicaroot: $ds_ldap_dc
nsds5replicaid: $instance_id
nsds5replicatype: 3
nsds5flags: 1
nsds5ReplicaPurgeDelay: 604800
nsds5ReplicaBindDN: $ds_repl_dn
EOF

#create the ou to store the binduser account in ds
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: ou=$ds_client_bind_ou,$ds_ldap_dc
changetype: add
objectclass: top
objectclass: organizationalUnit
ou: $ds_client_bind_ou
description: ou for bind account
EOF

#create the binduser for client auth
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: $ds_client_bind_dn
changetype: add
objectClass: inetorgperson
objectClass: person
objectClass: top
cn: $ds_client_bind_user
sn: sync
userPassword: $ds_client_bind_pw
EOF

#enable the memberOf plugin
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=MemberOf Plugin,cn=plugins,cn=config
changetype: modify
replace: nsslapd-pluginEnabled
nsslapd-pluginEnabled: on
-
replace: memberofgroupattr
memberofgroupattr: uniqueMember
-
replace: memberofattr
memberofattr: memberOf
-
EOF

#create the directory manager password file
#required for the memberOf fixup task and a couple command aliases
pwdfile=/etc/dirsrv/slapd-$HOSTNAME/dman.txt
printf $ds_mgr_pass > $pwdfile
chmod -v 400 $pwdfile
chown -v nobody:nobody $pwdfile

#create the memberOf fixup scheduled task
fixup_script='/etc/cron.hourly/memberofFixup.sh'
cat > $fixup_script <<EOF
/usr/lib64/dirsrv/slapd-$HOSTNAME/fixup-memberof.pl -D "cn=directory manager" -j $pwdfile -b "$ds_ldap_dc"
EOF

chmod -v +x $fixup_script
chown -v root:root $fixup_script

#restart to apply the changes
service dirsrv restart

#import the ssl db's for the dirsrv instance
dscertdir="/etc/dirsrv/slapd-$HOSTNAME"
#TODO: change to mv and keep rmdir
cp -fv ./certdbs/* $dscertdir
#rmdir -v /etc/spacewalk/certdbs
chown -v nobody:nobody $dscertdir
chmod -v 600 $dscertdir/*.db
#set the proper selinux security context for the db files
chcon -t dirsrv_config_t $dscertdir/*.db &>/dev/null || echo "selinux is disabled, continuing"

#add the Windows CA as a trusted CA to the global cert db
windows_ca_file="/tmp/windows-ca.cer"
windows_ca_nickname="windows-CA"
echo "$windows_ca" > $windows_ca_file
#certutil -A -n "$windows_ca_nickname" -t "TC,TC,TC" -d $cacertdir -i $windows_ca_file
#add it to the slapd instance as well
certutil -A -n "$windows_ca_nickname" -t "TC,TC,TC" -d $dscertdir -i $windows_ca_file
rm -fv $windows_ca_file

#create the pin file so dirsrv starts without prompting for the ssl db password
pinfile=/etc/dirsrv/slapd-$HOSTNAME/pin.txt
echo "Internal (Software) Token:$ds_ssl_pass" > $pinfile
chown -v nobody:nobody $pinfile
chmod -v 400 $pinfile

#enable ssl in ds
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=config
changetype: modify
replace: nsslapd-security
nsslapd-security: on
-
replace: nsslapd-ssl-check-hostname
nsslapd-ssl-check-hostname: off
-
EOF

ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=encryption,cn=config
changetype: modify
replace: nsSSL3
nsSSL3: on
-
replace: nsKeyfile
nsKeyfile: alias/slapd-$HOSTNAME-key3.db
-
replace: nsCertfile
nsCertfile: alias/slapd-$HOSTNAME-cert8.db
-
EOF

ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=RSA,cn=encryption,cn=config
changetype: add
nsSSLToken: internal (software)
nsSSLPersonalitySSL: dirsrv-wildcard-cert
nsSSLActivation: on
objectClass: top
objectClass: nsEncryptionModule
cn: RSA
EOF

service dirsrv restart
echo "ssl configuration complete."

#before configuring AD sync, see if any of the configured recovery hosts already
#have a replica of the domain (eg. is this a failed primary master scenario?)
./directory_recover_bridgehead.sh $1

ou_sync_script="/etc/cron.hourly/sync-ous.sh"
#the parser python script minus the .py extension
parser="/usr/sbin/parse_ldif"

#create the sync script
cat > $ou_sync_script <<EOF
#!/bin/bash
set -e
#grab all ous from AD
ldapsearch -H ldaps://$ds_ad_sync_target -D "$ds_ad_sync_dn" -w '$ds_ad_sync_pw' -b $ds_ldap_dc "ou=*" > /tmp/input.ldif
#build the ds-friendly sorted ldif file
$parser /tmp/input.ldif > /tmp/import.ldif
#add the ous to ds
ldapadd -cv -D "cn=directory manager" -w '$ds_mgr_pass' -f /tmp/import.ldif || echo "info: one or more OUs already exist"
EOF

chmod -v +x $ou_sync_script
chown -v root:root $ou_sync_script

chmod -v +x $parser
chown -v root:root $parser

#immediately run the ou sync so the ad replication can initialize everything during
#the first run later.
$ou_sync_script

#enable and configure the posix sync plugin
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=Posix Winsync API,cn=plugins,cn=config
changetype: modify
replace: nsslapd-pluginEnabled
nsslapd-pluginEnabled: on
-
replace: posixWinsyncMapMemberUID
posixWinsyncMapMemberUID: true
-
replace: posixWinsyncCreateMemberOfTask
posixWinsyncCreateMemberOfTask: true
-
replace: posixWinsyncLowerCaseUID
posixWinsyncLowerCaseUID: true
-
EOF

#dirsrv hangs on restart after enabling the posix sync plugin on a recovered master for some reason
#need to send sigkill before continuing
killall ns-slapd -s SIGKILL
service dirsrv start

#create the Users container to store the AD bind user account on the ds side
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF || echo "ou $ds_ad_sync_user_ou already exists"
dn: ou=$ds_ad_sync_user_ou,$ds_ldap_dc
changetype: add
objectclass: top
objectclass: organizationalUnit
ou: $ds_ad_sync_user_ou
description: default container to mirror the AD side
EOF

#create the AD sync user
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF || echo "user $ds_ad_sync_user already exists"
dn: $ds_ad_sync_dn
changetype: add
objectClass: inetorgperson
objectClass: person
objectClass: top
cn: $ds_ad_sync_user
sn: sync
userPassword: $ds_ad_sync_pw
EOF

#add the user to the directory admins group
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF || echo "user $ds_ad_sync_user already a directory admin"
dn: cn=Directory Administrators,$ds_ldap_dc
changetype: modify
add: uniqueMember
uniqueMember: $ds_ad_sync_dn
EOF

#add the AD binddn to the db
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF || echo "AD binddn already present"
dn: cn=replica,cn="$ds_ldap_dc",cn=mapping tree,cn=config
changetype: modify
add: nsDS5ReplicaBindDN
nsDS5ReplicaBindDN: $ds_ad_sync_dn
EOF

#add the replication agreement
agreement_name="AD-repl-agreement"
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=$agreement_name,cn=replica,cn=$ds_ldap_dc_escaped,cn=mapping tree,cn=config
changetype: add
objectClass: top
objectClass: nsDSWindowsReplicationAgreement
description: AD replication from $ds_ad_sync_target
cn: $agreement_name
nsds7WindowsReplicaSubtree: $ds_ldap_dc
nsds7DirectoryReplicaSubtree: $ds_ldap_dc
nsds7NewWinUserSyncEnabled: on
nsds7NewWinGroupSyncEnabled: on
nsds7WindowsDomain: $ds_ad_suffix
nsDS5ReplicaRoot: $ds_ldap_dc
nsDS5ReplicaHost: $ds_ad_sync_target
nsDS5ReplicaPort: 636
nsDS5ReplicaBindDN: $ds_ad_sync_dn
nsDS5ReplicaTransportInfo: SSL
nsDS5ReplicaBindMethod: SIMPLE
nsDS5ReplicaCredentials: $ds_ad_sync_pw
oneWaySync: fromWindows
winSyncInterval: $ds_ad_sync_interval
EOF

#initialize the agreement
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=$agreement_name,cn=replica,cn=$ds_ldap_dc_escaped,cn=mapping tree,cn=config
changetype: modify
replace: nsds5BeginReplicaRefresh
nsds5BeginReplicaRefresh: start
EOF

#Updating DB Cache Size
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=config,cn=ldbm database,cn=plugins,cn=config
changetype: modify
replace: nsslapd-dbcachesize
nsslapd-dbcachesize: 20971520
EOF

#Updating nslapd memcache size
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=userRoot,cn=ldbm database,cn=plugins,cn=config
changetype: modify
replace: nsslapd-cachememsize
nsslapd-cachememsize: 20971520
EOF

#updating nslapd dnmemcace size
ldapmodify -v -D "cn=directory manager" -w $ds_mgr_pass <<EOF
dn: cn=userRoot,cn=ldbm database,cn=plugins,cn=config
changetype: modify
replace: nsslapd-dncachememsize
nsslapd-dncachememsize: 20971520
EOF

logger "$0: waiting on $agreement_name to replicate"
while true; do
    sleep 1
    ldapsearch -H ldaps://$(hostname -f) -D "cn=directory manager" -w $ds_mgr_pass -b cn=config "cn=$agreement_name" | grep -i 'nsds5replicaLastInitStatus: 0 Total update succeeded' && break
done
logger "$0: replication complete for $agreement_name"

#update all memberOf attrs using the fixup script
$fixup_script || logger "$0: failed to run $fixup_script"

#create the operational scripts
ad_resync_script="/usr/sbin/directory_reinitialize_ad_sync"
cat > $ad_resync_script <<ENDSCRIPT
#!/bin/bash
set -e

ldapmodify -v -D "cn=directory manager" -y /etc/dirsrv/slapd-\$HOSTNAME/dman.txt <<EOF
dn: cn=AD-repl-agreement,cn=replica,cn=$ds_ldap_dc_escaped,cn=mapping tree,cn=config
changetype: modify
replace: nsds5BeginReplicaRefresh
nsds5BeginReplicaRefresh: start
EOF
ENDSCRIPT
chmod -v +x $ad_resync_script

ds_resync_script="/usr/sbin/directory_reinitialize_ds_sync"
cat > $ds_resync_script <<ENDSCRIPT
#!/bin/bash
set -e

function show_help {
	echo "usage: \$0 [-a repl_agreement_name]"
}

while getopts "ha:" opt; do
	case "\$opt" in
	h)  show_help
		exit 0
		;;
	a)  AGREEMENT_NAME=\$OPTARG
		;;
	esac
done

if [ -z "\$AGREEMENT_NAME" ]; then
	show_help
	exit 1
fi

ldapmodify -v -D "cn=directory manager" -y /etc/dirsrv/slapd-\$HOSTNAME/dman.txt <<EOF
dn: cn=\$AGREEMENT_NAME,cn=replica,cn="$ds_ldap_dc",cn=mapping tree,cn=config
changetype: modify
replace: nsds5BeginReplicaRefresh
nsds5BeginReplicaRefresh: start
EOF
ENDSCRIPT
chmod -v +x $ds_resync_script

lsdomain="/usr/sbin/lsdomain"
cat > $lsdomain <<EOF
#!/bin/bash
ldapsearch -H ldaps://\$(hostname -f) -D "cn=directory manager" -y "/etc/dirsrv/slapd-\$HOSTNAME/dman.txt" -b "$ds_ldap_dc" \$@
EOF

lsconfig="/usr/sbin/lsconfig"
cat > $lsconfig <<EOF
#!/bin/bash
ldapsearch -H ldaps://\$(hostname -f) -D "cn=directory manager" -y "/etc/dirsrv/slapd-\$HOSTNAME/dman.txt" -b "cn=config" \$@
EOF

chmod -v +x $lsdomain
chmod -v +x $lsconfig

