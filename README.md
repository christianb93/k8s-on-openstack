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
* labXXX - one directory for each lab

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

Of course you will need Ansible and Terraform. I used Ansible 2.8.6 (install with `pip3 install ansible==2.8.6`) and Terraform v0.12.10 (note that some versions of Ansible around 2.9 have a broken OpenStack network module). When you want to validate the install, you will also need an OpenStack client (`apt-get install python3-openstackclient`) and kubectl (`curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubectl')

# Running 

To run a full installation, the following steps are needed (assuming that you have cloned this repository and your current working directory is the directory in which this README is located). We also assume that you have copied the service account key created above into this directory as well. First, run the Ansible playbooks that create the base environment in GCE and bring up the OpenStack environment 

```
ansible-playbook site.yaml
```

Once this command completes, your OpenStack cluster is up and running, and three instances (which will be our master node and two worker nodes) have been spawned. You should be able to log into each of these instances using

```
ssh -t network "source k8s-openrc ; openstack server ssh --identity=os-default-key --login=ubuntu --public master"
```

for the master (and similarly for worker1 and worker2). At this point, the cloud-config init scripts will have initialized the first network interface (attached to the management interface), but the underlay network device is not yet configured. 

Now let us run the actual Kubernetes installation:

```
ansible-playbook -i .state/config/cluster.yaml cluster/cluster.yaml
```

We can now already test our installation, assuming that a kubectl binary is installed on the lab host. For instance, we can run

```
kubectl --kubeconfig .state/config/admin-kubeconfig get clusterroles
```

and should see the standard cluster-level roles that Kubernetes will create for us. If you have an OpenStack client installed locally, you can also use that to access our OpenStack installation, for instance via

```
source .state/credentials/k8s-openrc
openstack server list
```

To destroy all resources again, run

```
cd base
terraform destroy -auto-approve
```

TBD: restart script cluster:

- recreate kubeconfig (contains network node IP)
- restart etcd (hangs sometimes)

