import yaml
from pyVim import connect
from pyVmomi import vmodl
from pyVmomi import vim
from pysphere import *

f = open('config.yaml')
config = yaml.load(f)
f.close()


def print_vm_info(vm, depth=1, max_depth=10):
	if hasattr(vm, 'childEntity'):
        if depth > max_depth:
            return
        vmList = vm.childEntity
        for c in vmList:
            print_vm_info(c, depth + 1)
        return

    summary = vm.summary
    print "Name       : ", summary.config.name
    print "Guest      : ", summary.config.guestFullName
    print "State      : ", summary.runtime.powerState
    if summary.guest is not None:
        ip = summary.guest.ipAddress
        if ip:
            print "IP         : ", ip   

server = VIServer()



server.connect(config["server"], config["user"], config["pass"])

