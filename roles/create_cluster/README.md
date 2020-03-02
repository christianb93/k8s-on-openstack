create_cluster
===============

This role prepares the cluster,  i.e. it creates a network, a router and three instances. Specifically, the following steps are carried out.

* Download the base image that we will use for all the instances and store it as *ubuntu-bionic* 
* Create an internal network "k8s-mgmt-network" and a corresponding subnet 
* create a router to connect this network to the external network

When the variable *create_kuryr_networks* is set to true, we will in addition create two additional networks both meant to be used by Kuryr - a pod network and a service network. For the service network, care needs to be taken as Kuryr will allocate IPs from this range for the VRRP ports of load balancers, while Kubernetes will use it to assign cluster IPs . To avoid conflicts, we have to use a smaller CIDR range for Kubernetes. Specifically, we use 10.2.0.0/25 as Kubernetes service CIDR, instead of the previously used 10.2.0.0/24, and create an OpenStack subnet starting at 10.2.0.128, with gateway 10.2.0.254. Thus the /24 network 10.2.0.0 will be split into a lower half, managed by Kubernetes and used for assigning clusterIPs, and an upper half, managed by Kuryr and used to assign VRRP IPs. Both Kuryr networks will be added as internal networks to the router.