external_ingress_controller
=========

This role installs an external (i.e. out-of-cluster) NGINX ingress controller on the access node which will listen on port 8080 (HTTP) and 4433 (HTTPS) for incoming requests and distribute them to services and pods according to the ingress rules defined in the cluster.


Prerequisites
------------

Recall that the NGINX ingress controller monitors ingress objects in the cluster and maintains the configuration of an NGINX server so that requests are loadbalanced to service endpoints according to the Ingress rules. The controller does not send traffic to the service cluster IP, but instead uses the service to extract the endpoints and then routes traffic directly to the endpoints. 

To make this work when the controller and the NGINX server are both running on the access node, we need to be able to reach pod IPs from the access node. For that purpose, we leverage the OpenStack cloud controller manager, which is able to configure routes in an OpenStack router according to the pod CIDRs. More specifically, the cloud controller will, for each worker node, add a route for the pod CIDR of the node using the node as gateway. Thus we can reach pod IPs from the access node by enabling this feature and adding a static route on the network node sending traffic with destination 10.1.0.0/16 (or whatever our cluster CIDR is) to the gateway IP of the OpenStack router. To allow the traffic to reach the nodes, we also need to add a security rule to the node security group which allows incoming traffic from the access node.

In addition, we also need to create configmaps that the NGINX controller expects to be present in the cluster. The *tcp-services* and *udp-services* config maps can be used to define layer 4 forwarding rules (which an Ingress object is not able to capture), while the *ingress-nginx* config map can be used to set additional options for the NGINX server started by the controller, as explained [here](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/).

The second preparation we need is a kubeconfig file. As the controller is running out-of-cluster, it cannot used a mapped service account token and thus we need to create and specify a kubeconfig file. For the sake of simplicity, we use the *admin-kubeconfig* file which we have created for the cluster admin (which is not exactly according to the principle of least privileges, but will do for our playground setup). 

There is an additional problem that we need to address. Actually, the controller is not designed to run out of cluster, but assumes that it is running inside a pod and behind a service. At startup, it will try to read the pod (using the environment variable *POD_NAME*) and the service, and will fail if one of them is not present. To avoid this, we create a dummy pod (simply running a loop) and a dummy service inside the cluster, even though the actual controller is running outside the cluster.

Configuration
--------------

To actually run the NGINX controller, we use Docker, as this allows us to simply download and run the pre-built Docker container. As we want to stay in control of the iptables configuration on the access node, we run the Docker engine with the switch *--iptables=false* so that the Docker engine will not create its own iptables rules, and place the container in the network namespace of the host. 

Here are a few additional configuration options that we set.

* annotations_prefix - this is the prefix used for annotations evaluated by the controller
* kubeconfig - the path to our kubeconfig file, which of course needs to be mounted into the container
* apiserver-host - the URL of the Kubernetes API server
* http-port - the port on which the NGINX server will listen for insecure HTTP requests 
* https-port - the port on which the NGINX server will listen for HTTPS requests 
* ingress-class - this is the value of the annotation  *kubernetes.io/ingress.class* which will indicate to the controller that it should process an ingress. Note that the controller will also process any ingress for which this annotation is not set at all!
* publish-status-address - by default, the controller will populate the status section of the ingress resource with the IP of the service behind which it is running. In our case, this is a dummy service, and we should in fact put the public IP of the access node into the status. This parameter allows us to override the service cluster IP which we use to make this work
* update-status - we set this to true to make sure that the status of an ingress is updated


Role Variables
--------------

The following variables need to be set when calling this role.

* cluster_cidr - the CIDR of the Kubernetes cluster, i.e. the pod network
* os.access_node.ip - the IP of the access node
* os.access_node.user - the user on the access node that we use for the installation 

For the following variable, a default is defined.

* nginx_controller_image - the image to use

Dependencies
------------

None


License
-------

MIT

Author Information
------------------

Visit me at https://www.github.com/christianb93
