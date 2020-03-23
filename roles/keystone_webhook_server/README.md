keystone_webhook_server
========================

This role install the Keystone webhook server which can be used to authenticate against the Kubernetes API using users and role maintained in Keystone. First, we need to build the binaries. To simplify this, I have prepared a Dockerfile which dowloads the source code and installs the necessary dependencies. To build and run this Dockerfile, enter the following commands.

```
cd roles/kubernetes_keystone
docker build -t kubernetes_keystone .
docker run \
  -v $(pwd):/binaries \
  kubernetes_keystone \
  go build -o /binaries/k8s-keystone-auth cmd/k8s-keystone-auth/main.go
docker run \
  -v $(pwd):/binaries \
  kubernetes_keystone \
  go build -o /binaries/client-keystone-auth cmd/client-keystone-auth/main.go
```

I have uploaded copies of the resulting executables to the Google storage bucket https://storage.googleapis.com/leftasexercise.com/kube-binaries/ in case you want to avoid the local build process. 

There are several options regarding the question where we run the Keystone webhook server. The server needs access to the Keystone API server, as well as (at least for advanced features) to the Kubernetes API server. One option would be to run the server in-cluster as a pod, but in our setup, pods and services are not easily reachable from the master node as kube-proxy and Flannel are not running on the master node. Therefore, we run the server as a systemd service on the master node. With this approach, the following installation steps are required:

* first, we need TLS certificates to secure the Keystone webhook server. We assume that these certificates are created by a separate role and can be copied to the master node
* we copy the certificates to the master node
* we create a systemd unit file for the server
* we download the server binary to the master node and start the service

In addition, we need to make sure that the Kubernetes API server has access to the webhook server. For that purpose, we need to create a configuration file in kubeconfig format which contains the URL of the webhook server and the credentials to access it, and we need to point the Kubernetes API server to this file *-authentication-token-webhook-config-file* parameter. Note that this is *not* done by this role, but needs to be done by the role installing the API server.

The following variables need to be set to run this role.

* keystone_webhook_server_cert_file - a path to a certificate that we use as server certificate for the Keystone webhook server
* keystone_webhook_server_private_key_file - a private key matching the certificate above
* keystone_webhook_binary_url - the URL of the Keystone webhook server binary
* ca_cert_data - the CA certificate for the above TLS certs, as unencoded data
* os_ca_cert_file - the CA certificate for the OpenStack API
* use_static_policy - set this to true to use a static policy file
* policy_file_name - the name of the policy file
* use_dynamic_policy - set this to true to use a dynamic policy, stored in a config map
* policy_config_map_name - the name of the config map (in the kube-system namespace)
* policy_kubeconfig - the name of a kubeconfig file, present on the master node, which the webhook server should use to read the config map
