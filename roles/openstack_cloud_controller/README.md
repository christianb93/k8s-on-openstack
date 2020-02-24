openstack_cloud_controller
=========

This role installs the OpenStack cloud controller manager. Here are a few points that need to be taken into account.

First, we have to understand how the cloud controller gets access to the Kubernetes API. We will be running our cloud controller in-cluster, so that we are facing the same chickend-and-egg problem as we did it for the kube-proxy, and we can use the same solution - we create a service account, use the Kubernetes service account mechanism to map the credentials into the pod and use a config map to provide a kubeconfig file referencing these credentials. We will run the cloud controller with an initial set of privileges (using the sample files provided [here](https://github.com/kubernetes/cloud-provider-openstack/tree/master/cluster/addons/rbac)) and  use the switch *--use-service-account-credentials* to instruct the controller to create additional service accounts as needed.

Next, we need to add some tolerations to our pod to make it run. When starting, the Kubelet will add two taints to each of the worker nodes.

  taints:
  - effect: NoSchedule
    key: node.cloudprovider.kubernetes.io/uninitialized
    value: "true"
  - effect: NoSchedule
    key: node.kubernetes.io/not-ready

The second taint is the taint that we have already seen, which is added because at this point, no CNI plugin is installed and therefore the node is not ready. The first taint is new - this taint is added by the Kubelet is an external cloud provider is used, and will only be removed by the cloud controller itself once it is running. So we need to add a corresponding toleration to avoid another chicken-egg problem, and we also need to run the cloud controller manager in the host network namespace.

We also need to make the cloud configuration file available. The easiest approach is to use a secret (not a config map, as the configuration contains the OpenStack credentials). The cloud configuration file also needs to contain a reference to the CA that the OpenStack client is supposed to use to verify server certificates. Again, the easiest approach to make this certificate available is to store it as a secret.



Requirements
------------

None

Role Variables
--------------

The following variables need to be set when calling this role.

* state_dir - path to the state directory
* cluster_name - the name of the cluster
* cluster_endpoint - cluster API endpoint (full URL)
* os_ca_cert_data - a CA certificate (the data itself, not the file) which the OpenStack cloud provider will use to verify the certificate presented by a secured OpenStack API endpoint

Dependencies
------------

None


License
-------

MIT

Author Information
------------------

Visit me at https://www.github.com/christianb93