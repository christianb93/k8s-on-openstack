Testing our installation
============================


In this document, we collect a few tests that can be run after the installation has finished to verify proper operations. First, of course, we want to make sure that we can connect to the OpenStack API and the Kubernetes API. To do this, enter

```
source .state/credentials/k8s-openrc
export KUBECONFIG=.state/config/admin-kubeconfig
openstack server list
kubectl get nodes -o wide
```

We should see the three OpenStack instances (a master and two worker nodes) and two Kubernetes nodes.  You can also verify that all OpenStack nodes are up and running, the command

```
openstack compute service list
```

should show you the scheduler and the conductor running on the controller node and a nova-compute service running on each of the compute nodes. If this is not the case, check the output of the Ansible scripts for errors and - if needed -re-run the scripts *base/base.yaml* and *os/os.yaml* separately.


# Basic deployments and services

Now let us create our first deployment, which will bring up two NGINX instances.

```
kubectl apply -f tests/test1.yaml
count=0
while [ $count != "2" ]; do
  sleep 2;
  count=$(kubectl get deployment nginx --no-headers -o custom-columns=":.status.availableReplicas")
done
```

Let us now create a bash array holding the pods and try to establish a connection from the first pod to the second pod

```
pods=( $(kubectl get pods --no-headers --selector "app==nginx" -o custom-columns=":metadata.name") )
kubectl exec ${pods[0]} -- /bin/sh -c "apt-get -y update && apt-get -y install curl"
kubectl exec ${pods[0]} -- /bin/sh -c "curl nginx-service"
```

If this works, we know that pod-to-pod communication across nodes is working, DNS resolution is working and the iptables magic that kube-proxy sets up to make services reachable is working as well. Finally, our service is of type node port and should therefore be reachable via a worker node. To test this, we SSH into the master, determine the node port assigned to the service and use curl to access it.


```
ssh -t network "source k8s-openrc ; openstack server ssh --identity=os-default-key --login=ubuntu --public master"
nodePort=$(kubectl --kubeconfig /etc/kubernetes/pki/kube-scheduler-config get svc nginx-service --no-headers -o custom-columns=":.spec.ports[0].nodePort")
curl worker1:$nodePort
exit
```


# Test hairpinning


 To test some hairpinning scenarios we force both pods of our Nginx deployment discussed earlier on the same node by killing one of the worker nodes (of course you will have to re-run the installs scripts afterwards to bring up the second worker node again)

```
openstack server delete worker2
kubectl delete node worker2
pods=( $(kubectl get pods --no-headers --selector "app==nginx" -o custom-columns=":metadata.name") )
for pod in ${pods[@]}; do
  kubectl delete pod $pod; 
done
kubectl get pods -o wide -w
```

After some time, you should see that both pods have been restarted on worker1. Now repeat the commands from above to install curl on the new pod as well and test that we can still reach the second pod. Now we can scale down the deployment to one pod and check that the pod can reach itself via the service ("hairpinning")

```
kubectl scale deployment.v1.apps/nginx --replicas=1
count=2
while [ $count != "1" ]; do
  sleep 2;
  count=$(kubectl get deployment nginx --no-headers -o custom-columns=":.status.availableReplicas")
done
pods=( $(kubectl get pods --no-headers --selector "app==nginx" -o custom-columns=":metadata.name") )
kubectl exec ${pods[0]} -- /bin/sh -c "apt-get -y update && apt-get -y install curl"
kubectl exec ${pods[0]} -- /bin/sh -c "curl nginx-service"
```

# Testing the OpenStack cloud provider

First, let us check the information that the cloud controller will add to a node. Specifically, let us look for the following information:

* the provider ID of the node that the controller will add to the spec
* the IP addresses of the node which will be added to the status section
* the instance type which will be added as label *beta.kubernetes.io/instance-type*
* the failure domain (label *failure-domain.beta.kubernetes.io/zone*)
* the region (label *failure-domain.beta.kubernetes.io/region*)


```
kubectl get node worker1 -o json | jq -r ".spec.providerID"
kubectl get node worker1 -o json | jq -r ".status.addresses"
kubectl get node worker1 -o json | jq -r ".metadata.labels[\"beta.kubernetes.io/instance-type\"]"
kubectl get node worker1 -o json | jq -r ".metadata.labels[\"failure-domain.beta.kubernetes.io/zone\"]"
kubectl get node worker1 -o json | jq -r ".metadata.labels[\"failure-domain.beta.kubernetes.io/region\"]"
```
If you compare the output of these commands to the output of 

``` 
openstack server show worker1 -f value -c id -c addresses worker1
openstack flavor show -f value -c id m1.medium
```

you should see that

* the providerID is the string "openstack:///" plus the UUID of the node in Openstack
* the instance type is the UUID of the flavor used for the node
* the addresses are the OpenStack node addresses, including the floating IP address

Now it is time to try out the load balancer integration. For that purpose, use the following command to spawn a service with two NGINX instances behind it.

```
kubectl apply -f tests/test2.yaml
```

Now run repeatedly

```
openstack loadbalancer list
kubectl get service nginx-loadbalancer-service
```
After typically a bit less than a minute, the load balancer should be displayed in the ACTIVE state, and an external IP should appear on the service. When you run

```
openstack floating ip list
```

and compare the output to the data displayed about the loadbalancer, you should see that the IP displayed as external service IP is the floating IP (on the external network, i.e. in the range 172.16.0.0/24) associated with the VIP (on the internal network, i.e. in the range 172.18.0.0/24)

Of course this IP is not reachable from our lab host, but from the network host. One way to test this is therefore to execute a curl on the network host via SSH.

```
vip=$(kubectl get service nginx-loadbalancer-service \
   -o json \
    | jq -r \
    ".status.loadBalancer.ingress[0].ip")
ssh network "curl $vip"
```    

You should now see the HTML source code of a typical NGINX welcome page. Alternatively, you can set up an SSH port forward

```
ssh -L 8888:$vip:80 -N network
```

and then point your browser to 127.0.0.1:8888 to see this page. Finally, you can delete the service again and should see the load balancer disappear.

# Testing Kuryr

Once the Kuryr controller and daemon are installed, we should see that all worker nodes move into the "Ready" status, indicating that the CNI configuration has successfully been validated by the Kubelet. To verify operations of the Kuryr controller, run 

```
./tests/test4.sh
```

This script will create four pods, each running a server process on port 8888, and try to ping each from from every other pod as well as a known IP address outside the cluster (8.8.8.8) from every pod. It will also test connectivity between pods, accessing a service IP, reaching an external IP and reaching the Kubernetes API endpoint.

Note that Kuryr will create a load balancer that should be visible in the output of `openstack loadbalancer list`. You should be able to verify that:

* the VIP of the load balancer is in the first half of the service CIDR
* the VRRP IP is in the second half of the CIDR range
* the load balancer pool has four members, corresponding to the four pods 

To see all this, use the following commands.

```
openstack loadbalancer show default/kuryr-demo-service
# Wait until loadbalancer is ACTIVE, then enter the following commands
pool=$(openstack loadbalancer show default/kuryr-demo-service -f value -c pools)
lb=$(openstack loadbalancer show default/kuryr-demo-service -f value -c id)
amphora=$(openstack loadbalancer amphora list --loadbalancer=$lb -f value -c id)
openstack loadbalancer amphora show $amphora
openstack loadbalancer member list $pool
```




