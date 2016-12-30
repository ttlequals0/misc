This automation assumes that the 389-ds package is available via a yum install.  To do this,
add the EPEL repo, then run:
```sh
./ds_scrub.sh
```
To remove any traces of directory server and install the correct packages.

Installing a new downstream directory server:
```sh
./deploy_ldap_server.sh downstream.conf
```

Installing a bridgehead:
```sh
./deploy_bridgehead.sh bridgehead.conf
```

To replace a directory server instance in-place on a host, first run:
```sh
./ds_scrub.sh
```

After the bridgehead is replaced, all downstream servers must be reinstalled as above for
replication to continue.  All directory servers should continue working while the bridgehead is down in the meantime.
