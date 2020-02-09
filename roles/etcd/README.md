Install etcd
=====================

This role will install the etcd daemon, based on the Bionic packages. We first create the needed certificates, place them in */etc/kubernetes/pki/*, then install the etcd using the APT package, adjust the parameters and restart.

The Ubuntu etcd package configures the etcd using environment variables. Here are the environment variables that we will change.

* ETCD_LISTEN_PEER_URLS, ETCD_INITIAL_ADVERTISE_PEER_URLS, ETCD_INITIAL_CLUSTER - we change this to use https and listen on the management interface. Note that the key used in the initial cluster configuration needs to match the name in ETC_NAME
* ETCD_LISTEN_CLIENT_URLS, ETCD_ADVERTISE_CLIENT_URLS - we also want to listen on a secure port on the management interface
* ETCD_CERT_FILE - this needs to point to the certificate that the etcd TLS server will present to clients (*/etc/kubernetes/pki/etcd_server.crt*)
* ETCD_KEY_FILE - similarly, this needs to point to the matching key pair
* ETCD_CLIENT_CERT_AUTH - this needs to be set to true to request client certificates
* ETCD_TRUSTED_CA_FILE - this needs to point to the etcd root CA file */etc/kubernetes/pki/etcd_ca.rsa* and will be used to verify client certificates
* for security reasons, we also set the corresponding options for peers, even though we do not use a cluster

There is a little twist with the bootstrapping procedure of the etcd, though. When we install the package, the configuration file as it comes with the package will be put in place, and the server will be started. When we now change the configuration, some changes are ignored because the member is already initialized. A first idea could be to first create the configuration file and then start the server, but this does not work either because we need to make the certificates readable for the etcd user which is only put in place once the packages are installed.

We therefore use the option *policy_rc_d* of the Ansible apt package to avoid that APT starts the server and start it manually once the configuration file is put in place.

Role variables:
=================

This role requires that the following variables are set:

* mgmt_ip - the IP of the node in the internal (management) network on which the etcd will listen