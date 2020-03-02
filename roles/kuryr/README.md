kuryr
============

## Prerequisites

This role install the Kuryr networking solution in our cluster. Installing Kuryr requires a few preparations. First, we need to build Docker images for Kuryr and push them into a public repository. We need one image for the Kuryr controller, which we will run as a single pod, and one image for the Kuryr daemon which should execute on every node and therefore needs to run as a daemon set.

To build the Docker image for the controller and push it into the registry, I have used the following commands 

```
cd roles/kuryr
docker build -t christianb93/kuryr:stein -f Dockerfile .
docker login
docker push christianb93/kuryr:stein
```

The image created this way is a bit more than 300 MB in size. This could probably optimized further (the image does, for instance, contain GCC which is required at build time, and a multi-stage build could be used to reduce this). However, we can use the same image for the controller, the daemon and the CNI plugin, so that we only have to download one image per node.

## Installation

The Kuryr controller will run as a pod. The following points need to be taken into account when preparings the manifest file.

* The controller needs access to the configuration. As it contains the OpenStack credentials, we store the configuration as a secret which is mounted into the pod. We can then use the *--config-file* command line switch to make the controller use this configuration
* We use a service account for the controller which we must create upfront. The list of access rights that are needed can be taken from the [devstack script](https://github.com/openstack/kuryr-kubernetes/blob/master/devstack/lib/kuryr_kubernetes) used to set up the controller on DevStack. 
* the controller needs to move network interfaces into the pods namespace and thus needs access to /proc, which we need to mount into the pod


TBD: turn of DHCP in pod and service subnet
TBD: security group rules to allow traffic to pods and API endpoint from service network?


The following variables need to be defined:

* state_dir - the state directory to which we will write our manifest files
* os.auth - authentication data for OpenStack as defined in config.yaml created during the execution of *os/os.yaml*
* os.install_node - information on the install node, from the same file
* pod_security_group_id - ID of a security group that we will add to each pod
* external_network_id - ID of the external network on which we create floating IPs for load balancers
* k8s_project_id - ID of OpenStack project in which we create resources
* kuryr_service_subnet_id - ID of service subnet
* kuryr_pod_subnet_id - ID of pod subnet
* node_network_id - ID of the network to which the nodes are attached

## Dependencies

We re-use the os-client-ca secret created during the installation of the OpenStack cloud provider. 


