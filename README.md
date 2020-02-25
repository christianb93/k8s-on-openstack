# k8s-on-openstack

This repository contains a collection of labs and Ansible scripts to deploy Kubernetes on top of OpenStack in Googles cloud platform. It is organized in labs, built on each other, where each lab describes one part of the setup. After completing all labs, we will have a Kubernetes environment on top of and integrated with OpenStack using the Kuryr CNI plugin, the OpenStack external cloud provider and a CSI plugin for Cinder, all running on a couple of nodes in Google's GCE.

We will be using Terraform to manage the GCE environment and Ansible to bring up OpenStack and Kubernetes. We will **not** use a tool like kubeadm, but instead create our own collection of scripts to install Kubernetes - simply because the main intent of this exercise is to understand how all this works and not to have a working configuration.

# Repository structure

This repository contains the following directories:

* roles - all Ansible roles that we need
* group_vars - groups variables that we need
* .state - this directory contains all state, like the Terraform state, credentials, certificates and other configuration information. This directory is not part of the repository, but will be created when the scripts are run
* base - this directory contains the scripts for the base platform, i.e. the Terraform templates for the GCE environment and Ansible scripts to prepare the state
* os - here we place the Ansible scripts to install OpenStack - taken from my blog [leftasexercise.com](https://leftasexercise.com/2020/01/20/q-running-your-own-cloud-with-openstack-overview/). This script also creates an external network and a m1.nano flavors for later tests
* nodes - this directory contains scripts needed to bring up our OpenStack nodes on which we will then install Kubernetes
* cluster - the final scripts for the Kubernetes cluster
* Lab1 - install the Kubernetes control plane
* Lab2 - install the worker nodes and add-ons
* Lab3 - install the OpenStack cloud controller manager
* Lab4 - use Flannel with the host-gw backend

The labs are structured as follows:

* Lab1 - install the control plane
* Lab2 - prepare and join the worker nodes, using Flannel as CNI provider


# Sizing of the environment

Here are some considerations regarding the sizing of the environment. For the Kubernetes node, we assume the following minimum sizing:

* 2 vCPUs, 4 GB RAM and 20 GB disk space for the master node
* 1 vCPU, 2 GB RAM and 10 GB disk space for the worker nodes

These instances will run on our GCE compute nodes. At the moment, we use two compute nodes, each with 2 vCPU and 7.5 GB of RAM. So the Kubernetes master node would be scheduled on one of the compute nodes and occupy both vCPUs there. The second compute node would then be able to hold two worker nodes, leaving even some RAM available. When we want to spin up additional services like a load balancer, we might need a third compute node. 


# Preparations

You will need a GCE account and a project in which our resources will be located. Assuming that you have an account, head to the [Google cloud console](https://console.cloud.google.com/), log in, click on the dropdown at the top which allows you to select a project and then click on "New project". Give your project a meaningful name, I used *k8s-on-openstack* for this. Google will then assign a globally unique project ID. Then select your new project, open the navigation bar and select "IAM & admin - Service accounts". Create a new service account, give it a meaningful name and description and hit "Create". 

Once the service account has been generated, you will need to assign a couple of roles. Here is the set of roles which I have used:

* Compute - Compute Instance Admin (v1)
* Compute - Compute Network Admin
* Compute - Compute Security Admin

Then continue and create a key. Select the file type JSON and store the downloaded file as *k8s-on-openstack-sa-key.json*. To enable your new project, you will have to use the console to visit the Compute Engine and VPC Network pages once. 

Of course you will need Ansible and Terraform. I used Ansible 2.8.6 (install with `pip3 install ansible==2.8.6`) and Terraform v0.12.10 (note that some versions of Ansible around 2.9 have a broken OpenStack network module). When you want to validate the install, you will also need an OpenStack client (`apt-get install python3-openstackclient`) and kubectl (`curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubectl`)

# Running 

To run a full installation, the following steps are needed (assuming that you have cloned this repository and your current working directory is the directory in which this README is located). We also assume that you have copied the service account key created above into this directory as well. First, run the Ansible playbooks that create the base environment in GCE and bring up the OpenStack environment 

```
ansible-playbook site.yaml
```

Once this command completes, your OpenStack cluster is up and running, and three instances (which will be our master node and two worker nodes) have been spawned. You should be able to log into each of these instances using

```
ssh -t network "source k8s-openrc ; openstack server ssh --identity=os-default-key --login=ubuntu --public master"
```

for the master (and similarly for worker1 and worker2). Note that it might take a couple of minutes for the instances to become available and to fully complete their startup procedure.

Now let us run the actual Kubernetes installation:

```
ansible-playbook -i .state/config/cluster.yaml cluster/cluster.yaml
```

We can now already test our installation, assuming that a kubectl binary is installed on the lab host. For instance, we can run

```
export KUBECONFIG=.state/config/admin-kubeconfig
kubectl get clusterroles
```

and should see the standard cluster-level roles that Kubernetes will create for us. If you have an OpenStack client installed locally, you can also use that to access our OpenStack installation, for instance via

```
source .state/credentials/k8s-openrc
openstack server list
```

Some test scenarios can be found in the tests directory. Once you are done, you might want to destroy all resources again. For that purpose, run

```
cd base
terraform destroy -auto-approve
```

To only destroy the network and servers in the cluster, run
```
source .state/credentials/k8s-openrc
servers=$(openstack server list -f value -c Name)
for server in $servers; do
  openstack server delete $server;
done
fips=$(openstack floating ip list -f value -c ID )
for fip in $fips; do
  openstack floating ip delete $fip;
done
openstack router remove subnet k8s-router k8s-node-subnet
openstack router delete k8s-router
for port in worker1-port worker2-port; do
  openstack port delete $port;
done
openstack network delete k8s-node-network
```

and then re-run *nodes/nodes.yaml* and *cluster/cluster.yaml*. 


# Binaries and versions used

This installation requires several binaries for the Kubernetes components and the Flannel CNI plugin. For convenience, I have put a version of these binaries into a Google storage bucket, where the installation scripts will retrieve them. If you want to use your own copies, you can of course modify the files in *groups_vars* accordingly. The default binaries that I use are from the following sources.

* The Kubernetes binaries are taken from [release 1.17.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.17.1), using the download links for the server and client binaries provided in the [release notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.17.md#downloads-for-v1171). Specifically, I downloaded [the server tar](https://dl.k8s.io/v1.17.1/kubernetes-server-linux-amd64.tar.gz) and [the node tar](https://dl.k8s.io/v1.17.1/kubernetes-node-linux-amd64.tar.gz), extracted them and uploaded the binaries to Google storage.
* The reference CNI plugins are taken from [release v0.8.5](https://github.com/containernetworking/plugins/releases/tag/v0.8.5), specifically from [this download link](https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz)
* The binaries of those components that we deploy as pods (like kube-proxy, Flannel or CoreDNS) are of course specified in the respective manifest files. For kube-proxy, we use release v1.17.1 as well. For Flannel, I use version v0.11.0-amd64, and CoreDNS is used in version 1.6.5
* The underlying OpenStack release is the Stein release, mostly taking from the official Ubuntu Bionic cloud archive

TBD: 

* fix deprecation message when using include in Ansible playbook
* when we restart, our script to update the tagging of the lb_port might fail if the OS API is not yet reachable
