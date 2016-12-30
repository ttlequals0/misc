#!/bin/bash

if [ "$1" == "" ] || [ "$1" == "--help" ]; then
  echo "Specify file name of rules to load"
  exit 0
fi

fname="$1"

if [ ! -f "$fname" ]; then
  echo "ERROR: file $fname does not exist"
  exit -1
fi

ovs-ofctl -O OpenFlow13 del-flows br0

# Create sed substitution field to switch ports 2.3.4.5 used in flow rules file to 
# to ports 10,11,12,13 used in script files
ss=""
ss="${ss}s/in_port=2/in_port=10/;"
ss="${ss}s/in_port=3/in_port=11/;"
ss="${ss}s/in_port=4/in_port=12/;"
ss="${ss}s/in_port=5/in_port=13/;"
ss="${ss}s/output:2/output:10/;"
ss="${ss}s/output:3/output:11/;"
ss="${ss}s/output:4/output:12/;"
ss="${ss}s/output:5/output:13/;"

# Read file '$fname' line by line and committ substitution
cat "$fname" | sed "$ss" | while read line ; do
  ovs-ofctl -O OpenFlow13 add-flow br0 "$line"
done

# ovs-ofctl -O OpenFlow13 dump-flows br0
