if [ -z $1 ]
then
    echo "Must supply an environment config file"
    exit -1;
fi
source $1


cat > /etc/sysconfig/named <<'EOF'
#Begin /etc/sysconfig/named
ENABLE_ZONE_WRITE=yes
OPTIONS=" -4"
#End /etc/sysconfig/named
EOF

cat > /etc/named.conf <<EOF
#Begin /etc/named.conf

acl allowed {
        localhost;
        localnets;
};

options {
        listen-on port 53 { any; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";

        recursion yes;
        allow-query     { any; };
        allow-query-cache { any; };
        allow-recursion { allowed; };

        bindkeys-file "/etc/named.iscdlv.key";
        managed-keys-directory "/var/named/dynamic";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "$dns_forward_zone" IN {
        type slave;
        file "zones/test.domain";
        allow-update { $dns_master_ip; };
};

zone "$dns_reverse_zone.in-addr.arpa" IN {
        type slave;
        file "zones/$dns_reverse_zone";
        masters { $dns_master_ip; };
};

zone "." in {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

#End /etc/named.conf
EOF

mkdir -pv /var/named/zones

service named start
chkconfig named on

