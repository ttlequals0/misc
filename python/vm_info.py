import yaml

from pysphere import *

f = open('config.yaml')
config = yaml.load(f)
f.close()

cluster = config["cluster"]

server = VIServer()
server.connect(config["server"], config["user"], config["pass"])
vms_in_server = server.get_registered_vms(cluster=(cluster))

for vsphere_vm in vms_in_server:
	virtual_machine = server.get_vm_by_path(vsphere_vm)
print virtual_machine.get_property('ip_address'), virtual_machine.get_property('hostname')