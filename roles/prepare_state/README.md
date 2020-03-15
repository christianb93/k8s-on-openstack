prepare_state_
=========

This role prepares the state required credentials for the installation. This includes credentials with OpenStack passwords, certificates for OpenStack and certificates for Kubernetes and etcd. 


First, we create a file credentials.yaml on the Ansible host if that does not yet exist and use pwgen to create comparatively secure passwords. Then we create an SSH key pair and distribute this key pair to all nodes. This is the key pair that we will use for our OpenStack instances.

We will also create a set of certificates for OpenStack:

* a first self-signed CA certificate that the certificate generator of Octavia will use (octavia_ca.crt and octavia_ca.rsa)
* a second self-signed certificate that we will use to issue certificates for OpenStack components (os_ca.crt and os_ca.rsa)
* a client_cert.pem file contaning a client certificate and the corresponding private key, signed by os_ca


The state directory will be structured as follows.

* ssh - contains SSH keys for instances
* tf - Terraform state
* ca - contains keys and certificates for the CAs
* credentials - credentials, i.e. OpenStack passwords
* os_certs - keys and certificates for OpenStack
* k8s_cert - keys and certificates for Kubernetes and etcd
* config - contains configuration data. All information that the later stages need about the OpenStack install go here, to make it easier to use the scripts with a different OpenStack installation



Requirements
------------

Make sure that the pwgen utility is installed on the Ansible host and OpenSSL is installed

Role Variables
--------------

The following variables are assumed to be set when calling this role:

* state_dir: the directory where the state is stored.
* access_node_ip - the public IP of the access node

Dependencies
------------

None


License
-------

MIT

Author Information
------------------

Visit me at https://www.github.com/christianb93
