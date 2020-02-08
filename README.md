# k8s-on-openstack

This repository contains a collection of labs and Ansible scripts to deploy Kubernetes on top of OpenStack in Googles cloud platform. It is organized in labs, built on each other, where each lab describes one part of the setup. After completing all labs, we will have a Kubernetes environment on top of and integrated with OpenStack using the Kuryr CNI plugin, the OpenStack external cloud provider and a CSI plugin for Cinder, all running on a couple of nodes in Google's GCE.

We will be using Terraform to manage the GCE environment and Ansible to bring up OpenStack and Kubernetes. We will **not** use a tool like kubeadm, but instead create our own collection of scripts to install Kubernetes - simply because the main intent of this exercise is to understand how all this works and not to have a working configuration.

# Repository structure

This repository contains the following directories:

* roles - all Ansible roles that we need
* group_vars - groups variables that we need
* .state - this directory contains all state, like the Terraform state, credentials, certificates and other configuration information. This directory is not part of the repository, but will be created when the scripts are run
* base - this directory contains the scripts for the base platform, i.e. the Terraform templates for the GCE environment and Ansible scripts to prepare the state
* os - here we place the Ansible scripts to install OpenStack - taken from my blog [leftasexercise.com](https://leftasexercise.com/2020/01/20/q-running-your-own-cloud-with-openstack-overview/)
* nodes - this directory contains scripts needed to bring up our OpenStack nodes on which we will then install Kubernetes
* cluster - the final scripts for the Kubernetes cluster
* labXXX - one directory for each lab


# Preparations

You will need a GCE account and a project in which our resources will be located. Assuming that you have an account, head to the [Google cloud consoe](https://console.cloud.google.com/), log in, click on the dropdown at the top which allows you to select a project and then click on "New project". Give your project a meaningful name, I used *k8s-on-openstack* for this. Google will then assign a globally unique project ID. Then select your new project, open the navigation bar and select "IAM & admin - Service accounts". Create a new service account, give it a meaningful name and description and hit "Create". 

Once the service account has been generated, you will need to assign a couple of roles. Here is the set of roles which I have used:

* Compute - Compute Instance Admin (v1)
* Compute - Compute Network Admin
* Compute - Compute Security Admin

Then continue and create a key. Select the file type JSON and store the downloaded file as *k8s-on-openstack-sa-key.json*. To enable your new project, you will have to use the console to visit the Compute Engine and VPC Network pages once. 

# Running 

To run a full installation, the following steps are needed (assuming that you have cloned this repository and your current working directory is the directory in which this README is located). We also assume that you have copied the service account key created above into this directory as well. 

```
ansible-playbook base/base.yaml
ansible-playbook os/os.yaml
```

To destroy all resources again, run

```
cd base
terraform destroy -auto-approve
```


