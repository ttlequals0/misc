
"""
Python script for listing detailed VM information
"""

import atexit
import yaml

from pyVim import connect
from pyVmomi import vmodl
from pyVmomi import vim

import argparse
import getpass


f = open('config.yaml')
config = yaml.load(f)
f.close()


def print_vm_info(vm, depth=1, max_depth=10):
    """
    Print information for a particular virtual machine or recurse into a
    folder with depth protection
    """

    # if group it will have children. if it does, recurse through them
    # and then return
    if hasattr(vm, 'childEntity'):
        if depth > max_depth:
            return
        vmList = vm.childEntity
        for c in vmList:
            print_vm_info(c, depth + 1)
        return
    vm_hardware = vm.config.hardware
    network_list = []

    for each_vm_hardware in vm_hardware.device:
        if (each_vm_hardware.key >= 4000) and (each_vm_hardware.key < 5000):
            network_list.append('{} | {} | {}'.format(each_vm_hardware.deviceInfo.label,
                                                         each_vm_hardware.deviceInfo.summary,
                                                         each_vm_hardware.macAddress))
    summary = vm.summary
    summaryhw = summary.runtime.host.summary.hardware
    print "Name       : ", summary.config.name
    print "Path       : ", summary.config.vmPathName
    print "Guest      : ", summary.config.guestFullName
    print('Memory     : {} GB'.format(summary.config.memorySizeMB / 1024)) 
    print('CPU Detail : Sockets: {}, Cores per Socket {}'.format(
        summaryhw.numCpuPkgs,
        (summaryhw.numCpuCores / summaryhw.numCpuPkgs)))
    print "State      : ", summary.runtime.powerState
    if summary.guest is not None:
        ip = summary.guest.ipAddress
        if ip:
            print "IP         : ", ip
    print 'Virtual NIC(s)     :', network_list[0]
    if len(network_list) > 1:
        network_list.pop(0)
        for each_vnic in network_list:
            print(each_vnic)
    print '-' * 100

def parse_service_instance(service_instance):
    """
    Print basic knowledge about environment 
    """

    content = service_instance.RetrieveContent()
    object_view = content.viewManager.CreateContainerView(content.rootFolder,
                                                          [], True)
    for obj in object_view.view:
        print obj
        if isinstance(obj, vim.VirtualMachine):
            print_vm_info(obj)

    object_view.Destroy()
    return


def main():
    """
    listing the virtual machines on a system.
    """

    try:
        service_instance = connect.SmartConnect(host=config["server"],
                                                user=config["user"],
                                                pwd=str(config["pass"]),
                                                port=int(config["port"]))

        if not service_instance:
            print("Could not connect to the specified host using specified "
                  "username and password")
            return -1

        atexit.register(connect.Disconnect, service_instance)

        # ## Do the actual parsing of data ## #
        parse_service_instance(service_instance)

    except vmodl.MethodFault, e:
        print "Caught vmodl fault : " + e.msg
        return -1

    return 0

# Start program
if __name__ == "__main__":
    main()