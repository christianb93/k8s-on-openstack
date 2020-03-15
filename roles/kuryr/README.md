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

The image created this way is a bit more than 300 MB in size. This could probably optimized further (the image does, for instance, contain GCC which is required at build time, and a multi-stage build could be used to reduce this). However, we can use the same image for the controller and the daemon, so that we only have to download one image per node.

Note that [this issue](https://github.com/eventlet/eventlet/issues/526) currently implies that we cannot use any version of Python3 newer than 3.6 to run the controller.

We use the Go based CNI client added with the Train release to have a small executable which will be placed on each worker node (this is not part of this role, see the *cni_plugin* role). I have uploaded a copy of the executable to Google storage to https://storage.googleapis.com/leftasexercise.com/kube-binaries/kuryr_cni. Unfortunately the Go implementation does not yet use Go modules, therefore we need to place the source code in the GOPATH. Here are the commands that I have used to build the image, using the Go version (1.10) coming with Ubuntu 18.04

```
cd $GOPATH/src/github.com
mkdir openstack
cd openstack
git clone https://github.com/openstack/kuryr-kubernetes.git
cd kuryr-kubernetes
git checkout stable/train
cd kuryr_cni
go get .
go build 
```

This will produce an executable kuryr_cni which I have then uploaded to Google storage. Note that we actually mix a piece of software from the Train release with the Stein release that we use for the other components, but as the API of the Kuryr daemon has not changed this still works. 



## Installation

The Kuryr controller will run as a pod. The following points need to be taken into account when preparings the manifest file.

* The controller needs access to the configuration. As it contains the OpenStack credentials, we store the configuration as a secret which is mounted into the pod. We can then use the *--config-file* command line switch to make the controller use this configuration
* We use a service account for the controller which we must create upfront. The list of access rights that are needed can be taken from the [devstack script](https://github.com/openstack/kuryr-kubernetes/blob/master/devstack/lib/kuryr_kubernetes) used to set up the controller on DevStack
* of course the controller needs to run in the host network namespace, as networking is not yet available when the controller starts
* and again, we need to add tolerations as the nodes are not yet ready when we try to schedule the controller 

For the Kuryr daemon, a few additional points are relevant.

* the daemon needs to move network interfaces into the pods namespace and thus needs access to /proc, which we need to mount into the pod
* the Kubelet expects a CNI configuration in /etc/cni/net.d and the CNI binary in /opt/cni/bin. To make this available, we create an init container which reads the configuration from a config map and copies it to /etc/cni/net.d/10-kuryr.conf
* the plugin also needs the *kuryr.conf* file which we therefore copy to the hosts */etc/kuryr/* directory as well
* we could proceed in a similar fashion with the binary, but we use a slightly different approach - similar to how the other CNI plugins are installed, we copy the Kuryr plugin to each worker node as part of the existing cni_plugins role

Finally, we have to create security group rules. As we use the default member mode ("layer 3 mode") for the Octavia load balancers created by Kuryr, the Octavia load balancer will try to reach each pod from the service subnet. Thus, we need to allow traffic from the service subnet into the node subnet. How to do this depends on the type of driver used. 

* If we use a driver that attaches the pods VIF directly to the OVS bridge, we need to make sure that the port of the pod allows incoming traffic from the service subnet. As Kuryr will automatically attach the security group configured via *pod_security_group_id* to each pod, we thus have to add a security group rule to this security group which allows incoming traffic from the service subnet. 
* If we use the MACVLAN driver (as we do it), this does NOT work, as the port attached to the pod is only used to reserve the IP address of the pod, and the traffic travels via the Neutron port attached to the worker node. Therefore, in this case, we have to add a corresponding rule to the security group of the worker node.

We also need a load balancer for the Kubernetes service itself, as Kuryr does only create load balancers for services with selectors, i.e. services backed by pods.

Also note that at the time of writing, Kuryr needs to be run with an admin user for OpenStack, as the default Octavia policy does only allow admin users to create load balancers (alternatively, you could of course adapt the policy and create a new role for that purpose).


The following variables need to be defined:

* state_dir - the state directory to which we will write our manifest files
* os.auth - authentication data for OpenStack as defined in config.yaml 
* os.access_node - information on the install node, from the same file
* pod_security_group_id - ID of a security group that we will add to each pod
* external_network_id - ID of the external network on which we create floating IPs for load balancers
* k8s_project_id - ID of OpenStack project in which we create resources
* kuryr_service_subnet_id - ID of service subnet
* kuryr_pod_subnet_id - ID of pod subnet
* node_subnet_id - ID of the subnet to which the nodes are attached

For the following variables, defaults are defined:

* kuryr_image: docker image to use

## Dependencies

We re-use the os-client-ca secret created during the installation of the OpenStack cloud provider. We also assume (see above) that the actual CNI plugin kuryr_cni has already been distributed via different means to all worker nodes and is installed in */opt/cni/bin*. 

The networks, load balancers and routers that we need are set up in the role *create_cluster* if the variable *create_kuryr_networks* is set.

## Troubleshooting

* If you cannot connect to a pod, check the annotations on the pod to verify that the pod has been detected by the Kuryr controller. For each pod, you should see a Neutron port being created and a reference to that port being added as an annotation to the pod
* also check that the IP address and MAC address of the pod have been added as an allowed address pair to the port of the worker node on which the pod has been scheduled
* keep in mind that services of type NodePort and ExternalName as well as UDP endpoints are not supported by Kuryr
