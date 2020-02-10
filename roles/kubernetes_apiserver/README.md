Install the Kubernetes API server
========================================

## Getting the binary

To be able to get the binary in a flexible way, we use the Ansible *get_url* module. The URL can either be a file URL (if, for  instance, we used a mapped volume in  Vagrant), or point to a donwload location. We do not want to download the full archive from the Github release page, so please download and extract this upfront and place the kube-apiserver binary somewhere where we can find it.

## Role variables

* kube_apiserver_binary_url - URL pointing to a location where we will download the API server
* mgmt_ip - the address to which the API server will be bound

