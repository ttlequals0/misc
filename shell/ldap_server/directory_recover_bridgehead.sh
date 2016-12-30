#!/bin/bash
set -e
if [ -z "$1" ]
then
    echo "Must supply an environment config file"
    exit -1;
fi
source $1

#try to find a recovery host
#if one exists and has data, assume that we're recovering and sync from that host
declare recovery_host
for host in ${ds_recovery_hosts[*]}; do
    echo "verifying recovery host $host"
    ldapsearch -H ldaps://$host -D "cn=directory manager" -w $ds_mgr_pass -b "$ds_ldap_dc" && rc=$? || rc=$?
    if [ $rc == 0 ]; then
        recovery_host=$host
    fi
done

if [ -z $recovery_host ]; then
    logger "$0: no valid recovery hosts found"
    #exiting 0 here so the primary_master setup script continues
    exit 0
fi

logger "$0: recovering from host $recovery_host"

#create a temporary replication agreement
master_fqdn=$(hostname -f)
agreement_name="$recovery_host-$master_fqdn-recovery-repl-agreement"
agreement_dn="cn=$agreement_name,cn=replica,cn=\"$ds_ldap_dc\",cn=mapping tree,cn=config"
excludes="authorityRevocationList memberOf"

#remove a previous recovery agreement if it exists for some reason
ldapdelete -H ldaps://$recovery_host -D "cn=directory manager" -w $ds_mgr_pass "$agreement_dn" && logger "$0: removed previous recovery agreement $agreement_name"

ldapmodify -H ldaps://$recovery_host -D "cn=directory manager" -w $ds_mgr_pass <<EOF >/dev/null
dn: $agreement_dn
changetype: add
objectclass: top
objectclass: nsds5replicationagreement
cn: $agreement_name
nsds5replicahost: $master_fqdn
nsds5replicaport: 636
nsds5replicatransportinfo: SSL
nsds5ReplicaBindDN: cn=replication manager,cn=config
nsds5replicabindmethod: SIMPLE
nsds5replicaroot: $ds_ldap_dc
description: temporary recovery repl agreement
nsds5replicatedattributelist: (objectclass=*) $ EXCLUDE $excludes
nsds5replicacredentials: $ds_repl_pass
nsds5BeginReplicaRefresh: start
EOF

logger "$0: waiting on $agreement_name to replicate"
while true; do
    sleep 1
    ldapsearch -H ldaps://$recovery_host -D "cn=directory manager" -w $ds_mgr_pass -b cn=config "cn=$agreement_name" | grep -i 'nsds5replicaLastInitStatus: 0 Total update succeeded' && break
done
logger "$0: replication complete for $agreement_name"

#dirsrv sometimes dies for some reason after the recovery repl completes
#make sure we're running before continuing
service dirsrv start

#remove the temporary agreement
ldapdelete -H ldaps://$recovery_host -D "cn=directory manager" -w $ds_mgr_pass "$agreement_dn"

logger "$0: recovery complete"
