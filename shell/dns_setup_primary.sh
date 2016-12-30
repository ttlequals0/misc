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
		rrset-order { type A order fixed; };

        bindkeys-file "/etc/named.iscdlv.key";
        managed-keys-directory "/var/named/dynamic";

		dnssec-enable no;
		dnssec-validation no;
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "$dns_forward_zone" IN {
        type master;
        file "zones/$dns_forward_zone";
        allow-update { allowed; };
};

zone "$dns_reverse_zone.in-addr.arpa" IN {
        type master;
        file "zones/$dns_reverse_zone";
        allow-update { allowed; };
};

zone "." in {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

#End /etc/named.conf
EOF

echo $dns_additional >> /etc/named.conf

mkdir -pv /var/named/zones

cat > /var/named/zones/$dns_forward_zone <<EOF
;Begin /var/named/zones/$dns_forward_zone
\$ORIGIN $dns_forward_zone.
\$TTL 86400;
@                       IN SOA  $dns_master_hostname.$dns_forward_zone. root.$dns_forward_zone. (
                                $(date +%Y%m%d%H)   ; serial
                                3600       ; refresh
                                1800       ; retry
                                604800     ; expire
                                86400      ; minimum
                                )
                        NS      $dns_master_hostname.$dns_forward_zone.
                        NS      $dns_slave_hostname.$dns_forward_zone.

$dns_master_hostname    A       $dns_master_ip
$dns_slave_hostname     A       $dns_slave_ip
spacewalk               A       $dns_master_ip
                        A       $dns_slave_ip
dir                     A       $dns_master_ip
                        A       $dns_slave_ip
;End /var/named/zones/24.300.10
EOF

cat > /var/named/zones/$dns_reverse_zone <<EOF
;Begin /var/named/zones/$dns_reverse_zone
\$ORIGIN $dns_reverse_zone.in-addr.arpa.
\$TTL 86400;
@                       IN SOA  $dns_master_hostname.$dns_forward_zone. root.$dns_forward_zone. (
                                $(date +%Y%m%d%H)   ; serial
                                3600       ; refresh
                                1800       ; retry
                                604800     ; expire
                                86400      ; minimum
                                )
                        NS      $dns_master_hostname.$dns_forward_zone.
                        NS      $dns_slave_hostname.$dns_forward_zone.

$(echo $dns_master_ip | awk -F. '{print $4}')                     PTR     $dns_master_hostname.$dns_forward_zone.
$(echo $dns_slave_ip | awk -F. '{print $4}')                     PTR     $dns_slave_hostname.$dns_forward_zone.
;End /var/named/zones/24.200.10
EOF

service named start
chkconfig named on

