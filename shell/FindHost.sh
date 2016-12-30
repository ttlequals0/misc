#!/bin/bash
#find host vm is running on within guest
IFS=$'\n'

for VM in $(vmware-cmd -l);
do
        VM_STATE=$(vmware-cmd "${VM}" getstate | awk -F "= " '{print $2}')
        if [ "${VM_STATE}" == "on" ]; then
                echo "Setting info for ${VM}"
                vmware-cmd "${VM}" setguestinfo hypervisor.hostname "$(hostname)"
                vmware-cmd "${VM}" setguestinfo hypervisor.build "$(vmware -v)"
        fi
done

unset IFS


vim-cmd vmsvc/getallvms | sed '1d' | awk '{if ($1 > 0) print $1":"$2}'
vim-cmd vmsvc/power.getstate <Vmid>


