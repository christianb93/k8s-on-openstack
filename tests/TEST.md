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



