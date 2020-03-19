# k8s-on-openstack

This repository contains a collection of labs and Ansible scripts to deploy Kubernetes on top of OpenStack in Googles cloud platform. It is organized in labs, built on each other, where each lab describes one part of the setup. After completing all labs, we will have a Kubernetes environment on top of and integrated with OpenStack using the Kuryr CNI plugin (in some of the labs), the OpenStack external cloud provider and a CSI plugin for Cinder, all running on a couple of nodes in Google's GCE.

We will be using Terraform to manage the GCE environment and Ansible to bring up OpenStack and Kubernetes. We will **not** use a tool like kubeadm, but instead create our own collection of scripts to install Kubernetes - simply because the main intent of this exercise is to understand how all this works and not to have a working configuration.

# Repository structure

This repository contains the following directories:

* roles - all Ansible roles that we need
* group_vars - groups variables that we need
* .state - this directory contains all state, like the Terraform state, credentials, certificates and other configuration information. This directory is not part of the repository, but will be created when the scripts are run
* gce - this directory contains the scripts for the base platform, i.e. the Terraform templates for the GCE environment, Ansible scripts to prepare the state and the Ansible scripts to install OpenStack - taken from my blog [leftasexercise.com](https://leftasexercise.com/2020/01/20/q-running-your-own-cloud-with-openstack-overview/). This script also creates an external network and a m1.nano flavors for later tests
* local - a directory used to bring up a local environment (see below)
* nodes - this directory contains scripts needed to bring up our OpenStack nodes on which we will then install Kubernetes
* cluster - the final scripts for the Kubernetes cluster
* labxxx - one directory for each lab

The labs are structured as follows:

* Lab1 - install the Kubernetes control plane
* Lab2 - install the worker nodes and add-ons
* Lab3 - install the OpenStack cloud controller manager
* Lab4 - use Flannel with the host-gw backend
* Lab5 - leverage the OpenStack router to build a network solution
* Lab6 - play with the Kuryr networking solution
* Lab7 - install the Cinder CSI plugins
* Lab8 - use the Octavia Ingress controller


# Sizing of the environment

Here are some considerations regarding the sizing of the environment. For the Kubernetes node, we assume the following minimum sizing:

* 2 vCPUs, 2 GB RAM and 20 GB disk space for the master node
* 1 vCPU, 1 GB RAM and 10 GB disk space for the worker nodes

These instances will run on our GCE compute nodes. At the moment, we use two compute nodes, each with 2 vCPU and 6 GB of RAM. This setup allows for a master node and three worker nodes plus potentially one or two Octavia load balancers. 


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
ansible-playbook gce/base.yaml
ansible-playbook gce/os.yaml
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
cd gce
terraform destroy -auto-approve
```


# Binaries and versions used

This installation requires several binaries for the Kubernetes components and the Flannel CNI plugin. For convenience, I have put a version of these binaries into a Google storage bucket, where the installation scripts will retrieve them. If you want to use your own copies, you can of course modify the files in *groups_vars* accordingly. The default binaries that I use are from the following sources.

* The Kubernetes binaries are taken from [release 1.17.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.17.1), using the download links for the server and client binaries provided in the [release notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.17.md#downloads-for-v1171). Specifically, I downloaded [the server tar](https://dl.k8s.io/v1.17.1/kubernetes-server-linux-amd64.tar.gz) and [the node tar](https://dl.k8s.io/v1.17.1/kubernetes-node-linux-amd64.tar.gz), extracted them and uploaded the binaries to Google storage.
* The reference CNI plugins are taken from [release v0.8.5](https://github.com/containernetworking/plugins/releases/tag/v0.8.5), specifically from [this download link](https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz)
* The binaries of those components that we deploy as pods (like kube-proxy, Flannel or CoreDNS) are of course specified in the respective manifest files. For kube-proxy, we use release v1.17.1 as well. For Flannel, I use version v0.11.0-amd64, and CoreDNS is used in version 1.6.5
* The underlying OpenStack release is the Stein release, mostly taken from the official Ubuntu Bionic cloud archive
* some labs use the Kuryr plugin, which is taken from the Train release - the Dockerfile and build instructions are in *roles/kuryr*



# Refreshing, stopping and restarting

To destroy all OpenStack resources created (i.e. instances, routers, floating IPs, networks and potentially load balancers), so that we can start over again with a fresh setup without having to delete the underlying resources, run

```
tools/refresh
```

and then, to recreate the OpenStack resources

```
ansible-playbook nodes/nodes.yaml
``` 

To reduce charges, it is advisable to stop all GCP instances when the environment is not used. The scripts are designed in such a way that when the instances come up again, the environment will be recovered and should be operating as normal, maybe after a short phase of a few minutes required to recreate all virtual machines and pods. 

In case the Terraform state is broken, you can also delete all resources in GCP manually by running `tools/gcloud_delete` from a Google cloud shell  - use this with care!

Also note that the Terraform script adds ingress firewall rules to allow traffic from your **current** IP address. If this changes, for instance because your provider disconnects you at some point at night and reconnects, you will have to run `(cd gce ; terraform apply -auto-approve)` to refresh the firewall rules.


# Running a local environment

If you have a machine with sufficient memory (at least 32 GB), you can also run the environment locally using Vagrant and VirtualBox. To do this, first run the following commands to bring up virtual machines, create an inventory and install OpenStack on the virtual machines. In contrast to previous labs where I used Vagrant and VirtualBox, this setup uses KVM as VirtualBox does not offer nested virtualization on Intel CPUs.

To run this example, there are a few one-time setup steps needed. First, we of course need to install KVM and the libvirt library. We also install the libvirt Python package which is required by Ansible's virt_net module.

```
sudo apt-get update && sudo apt-get install libvirt-daemon libvirt-clients libvirt-manager python3-libvirt
sudo adduser $(id -un) libvirt
sudo adduser $(id -un) kvm
# Log in again to get new group assigment
su -l $(id -un)
```

The next commands install the [libvirt Vagrant plugin](https://github.com/vagrant-libvirt/vagrant-libvirt) which allows us to define and run KVM based virtual machines using Vagrant files, download and resize a base box, and download images for the nodes and the Octavia amphora (in the GCE setup, we download these files directly to the nodes where we need them, in our local setup, it is more efficient to download them once and to map them into the virtual machine). 

```
vagrant plugin install vagrant-libvirt
sudo tools/prepareUbuntuBionicBox.sh
(cd local ; wget https://s3.eu-central-1.amazonaws.com/cloud.leftasexercise.com/amphora-x64-haproxy.qcow2)
(cd local ; wget http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img)
```

With this, our one-time setup is complete. To create and prepare our OpenStack environment, now simply execute

```
ansible-playbook local/up.yaml
ansible-playbook -i local/hosts.ini local/base.yaml
ansible-playbook -i local/hosts.ini local/os.yaml
```

Once these commands complete, you can now proceed to bring up the cluster and Kubernetes as usual, for instance using

```
ansible-playbook nodes/nodes.yaml
ansible-playbook -i .state/config/cluster.yaml cluster/cluster.yaml
```

Note that, as this configuration currently still uses the same state directory as the GCE based configuration, it should not be run in the same tree as the GCE based configuration. 







