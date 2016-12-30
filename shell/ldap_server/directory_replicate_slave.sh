#!/bin/bash
#sets up replication to this ds instance from the upstream ds instances in this environment
set -e
if [ -z "$1" ]
then
    echo "Must supply an environment config file"
    exit -1
fi
source $1

if [ -z $ds_upstream_hosts ]; then
    logger "$0: no upstream hosts found in this environment"
    exit -1
fi

consumer=$(hostname -f)
for supplier in ${ds_upstream_hosts[*]}; do
    logger "$0: configuring replication to $consumer from $supplier"

    agreement_name="$supplier-$consumer-repl-agreement"

    ldapmodify -H ldaps://$supplier -D "cn=directory manager" -w $ds_mgr_pass <<EOF >/dev/null || logger "$0: $agreement_name already exists"
dn: cn=$agreement_name,cn=replica,cn="$ds_ldap_dc",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replicationagreement
cn: $agreement_name
nsds5replicahost: $consumer
nsds5replicaport: 636
nsds5replicatransportinfo: SSL
nsds5ReplicaBindDN: cn=replication manager,cn=config
nsds5replicabindmethod: SIMPLE
nsds5replicaroot: $ds_ldap_dc
description: agreement between $supplier and $consumer
nsds5replicatedattributelist: (objectclass=*) $ EXCLUDE authorityRevocationList memberOf
nsds5replicacredentials: $ds_repl_pass
EOF

    ldapmodify -H ldaps://$supplier -D "cn=directory manager" -w $ds_mgr_pass <<EOF >/dev/null
dn: cn=$agreement_name,cn=replica,cn="$ds_ldap_dc",cn=mapping tree,cn=config
changetype: modify
replace: nsds5BeginReplicaRefresh
nsds5BeginReplicaRefresh: start
EOF

    logger "$0: waiting on $agreement_name to replicate"
    while true; do
        sleep 1
        ldapsearch -H ldaps://$supplier -D "cn=directory manager" -w $ds_mgr_pass -b cn=config "cn=$agreement_name" | grep -i 'nsds5replicaLastInitStatus: 0 Total update succeeded' && break
    done
    logger "$0: replication complete for $agreement_name"
done
logger "$0: all replication complete for $consumer"

#update all memberOf attrs using the fixup script
fixup_script="/etc/cron.hourly/memberofFixup.sh"
$fixup_script || logger "$0: failed to run $fixup_script"
