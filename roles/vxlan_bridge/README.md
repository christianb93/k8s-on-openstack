vxlan_bridge
=========

This role will create an OVS bridge and

* create a patch port on that bridge
* connect the patch port to an existing OVS patch port
* establish a VXLAN tunnel to a given list of other nodes 
* assign an IP address to the bridge and bring up the bridge interface


Requirements
------------

We assume the OVS is installed on the node on which we operate

Role Variables
--------------

The following variables need to be set when invoking this role:

* bridge_name - the name of the bridge that we create
* patch_port_local_name - the name of the local patch port that is created
* patch_port_peer_name - the name of the existing patch port to which we connect
* vxlan_nodes - IP address of other nodes to which we connect the bridge
* vxlan_id - the VXLAN ID (segmentation ID) that we use
* bridge_ip_address - the IP address of the bridge
* bridge_mtu - the MTU of the bridge 

We also make the configuration persistent. Note that the networking systemd service is brought up before the OVS switch systemd service, so we are in trouble if we want to configure OVS interface via ifup. Fortunately, there is a way to create bridges and ports directly via ifup, see [here](http://metadata.ftp-master.debian.org/changelogs/main/o/openvswitch/testing_openvswitch-switch.README.Debian)

Dependencies
------------

None


License
-------

MIT

Author Information
------------------

Visit me at https://www.github.com/christianb93
