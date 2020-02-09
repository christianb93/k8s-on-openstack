create_cluster
===============

This role prepares the cluster,  i.e. it creates a network, a router and three instances. Specifically, the following steps are carried out.

* Download the base image that we will use for all the instances and store it as *ubuntu-bionic* 
* Create an internal network "k8s-mgmt-network" and a corresponding subnet 
* create a router to connect this network to the external network

