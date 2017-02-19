ucat wl-28.93.1-0-orbitz-wl-us1-047.log |grep 20140811-13 |logdecode |grep '|E|' | awk -F'|' '{print $10}' | uniq -c | sort -nr | head

grun -t -h web-wl |grep wl-us |sort -k3nr |head

errors  -l -f10  -h web-wl-apac -s wl-apac1-009.cpeg.orbitz.net

sudo service glu-agent stop ; sudo rm /opt/glu/agent-server/data/config/agent.properties ; sudo service glu-agent start
  
wl-eu1-035 wl-28.87-0]$ cat  wl-28.87-0-orbitz-wl-eu1-035.log* |grep "20140709-09*" | logdecode | grep '|E|' | cut -d'|' -f10 | sort | uniq -c | sort -n  | tail

 grun -h satellite -R 'grep 23/Sep/2014:0[345]: /opt/orbitz/services/log/satellite-1.129-0/satellite-1.129-0-access-log.log | cut -f1 -d" " | cut -f1-2 -d"."  ' | sort | uniq -c | sort -rn | head -20

 find /opt/orbitz/solr/data/*/snapshot* -type d -mtime  +7 -exec du -h '{}' \;

curl -s "http://graphite.orbitz.com/render/?width=588&height=310&_salt=1425077521.148&target=PROD-WM.streambase.wl.wl-*_cpeg_orbitz_net.0.JvmStats.Thread.average&rawData=true"
|cut -d "." -f 4 |tr "_" "."

sudo -S -u orbitz /opt/orbitz/netscaler/bin/netscaler list -e production --all > /home/dkrachtus/vip_names < /home/dkrachtus/.secret && for i in  $(cat promo.list); do scp /home/dkrachtus/vip_names $i:/home/dkrachtus/; done >/dev/null 2>&1

servers=$(curl -s "http://graphite.orbitz.com/render/?width=588&height=310&_salt=1426364196.76&target=highestCurrent(PRODu-WM.streambase.wl.wl-*_cpeg_orbitz_net.0.JvmStats.Thread.average%2C5)&rawData=true"|cut -d "." -f 4 |tr "_" "."|tr "\n" ","| sed 's/,$/\n/') && gluadmin -B -s $servers -e staging -c -x

grun -x -h production-wm -e production-wm -R 'df -h | egrep "9[3456789]%|100%" ' | grep -B2 "%" | egrep -v "^[[:space:]]*$|\-\-"a

WL_LIST=$(for i in $(seq -w 094 125) ; do echo wl-$i-cpwm.orbitz.net  | tr "\n" "," |sed 's/,$/ /' ;  done) && gluadmin -R -n 180 -s $WL_LISTl -e production-wm

find /opt/orbitz/solr/data -regextype posix-extended -regex  ".*/snapshot.[0-9]{1,16}" -type d


