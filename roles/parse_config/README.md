parse_config
============

This role parses an OpenStack configuration file as created by the role *os_config* and uses that to add the install host to the dynamic inventory. It assumes that we have read the configuration file before running this role, using for instance *include_vars*.


# Variables

The following variables are assumed to be set (usually from the config.yaml):

* os.access_node.ip - the public IP of the install node
* os.access_node.user - the Ansible SSH user to reach this host 
* os.access_node.ssh_key - the private key file to use to establish the connection


