#!/bin/bash

#
# Wait until all pods of a deployment are ready. 
# Parameters:
# $1 - the name of the deployment
#
function wait_for_deployment {
    expected=$(kubectl get deployment kuryr-demo --no-headers -o custom-columns=":.spec.replicas")
    count=0
    while [ $count != "$expected" ]; do
        sleep 2;
        count=$(kubectl get deployment $1 --no-headers -o custom-columns=":.status.availableReplicas")
    done
    return 0
}

#
# Get the IP address of a pod 
# Parameter: 
# $1 - the pod
#
function get_pod_ip {
     kubectl get pod $1 --no-headers -o custom-columns=":.status.podIP"
}

#
# Determine directories that we need
#
scriptdir=$( cd $(dirname "${BASH_SOURCE[0]}") && pwd)
statedir=$scriptdir/../../.state

#
# Get credentials
#
source $statedir/credentials/k8s-openrc
export KUBECONFIG=$statedir/config/admin-kubeconfig

#
# Create deployment
#
kubectl apply -f $scriptdir/kuryr.yaml
#
# and wait for pods to come up
#
wait_for_deployment "kuryr-demo"

errors=0


#
# Now get all pods and send pings for every combination of pods
#
pods=( $(kubectl get pods --no-headers --selector "app==kuryr-demo" -o custom-columns=":metadata.name") )
for src_pod in "${pods[@]}"; do
    for tgt_pod in "${pods[@]}"; do
        if [ "$tgt_pod" != "$src_pod" ]; then
            tgt_ip=$(get_pod_ip $tgt_pod)
            echo "$src_pod ---> $tgt_pod ($tgt_ip)"
            kubectl exec $src_pod -- ping -c 1 $tgt_ip  > /dev/null 2>&1
            success=$?
            if [ "$success" != "0" ]; then
                echo -e "\033[31mPing from $src_pod to $tgt_ip (pod $tgt_pod) failed \033[0m"
                let errors++
            fi
        fi
    done
done

#
# Go through the pods once more and ping a known server in the outside world
#
for src_pod in "${pods[@]}"; do
    echo "$src_pod ---> 8.8.8.8"
    kubectl exec $src_pod -- ping -c 1 8.8.8.8  > /dev/null 2>&1
    success=$?
    if [ "$success" != "0" ]; then
        echo -e "\033[31mPing from $src_pod to 8.8.8.8 failed \033[0m"
        let errors++
    fi
done


#
# Now wait for the loadbalancer to be ACTIVE
#
lb_state="x"
attempts=0
while [ "$lb_state" != "ACTIVE" ]; do
    sleep 3;
    lb_state=$(openstack loadbalancer show default/kuryr-demo-service -f value -c provisioning_status)
    let attemps++
    if [ "$attempts" -gt "32" ]; then 
      echo -e "\033[31mTimed out while waiting for load balancer \033[0m"
      exit 1
    fi
done

echo "Load balancer is active, now waiting for members"

#
# Wait until all members are up
#
members="0"
attempts=0
while [ "$members" != "4" ]; do
    sleep 1;
    members=$(openstack loadbalancer pool show default/kuryr-demo-service:TCP:80 -f value -c members | wc -l)
    let attemps++
    if [ "$attempts" -gt "32" ]; then 
      echo -e "\033[31mTimed out while waiting for load balancer members\033[0m"
      exit 1
    fi
done


echo "All load balancer members configured, running tests against load balancer endpoint"
vip=$(kubectl get svc kuryr-demo-service --no-headers -o custom-columns=":spec.clusterIP")
for src_pod in "${pods[@]}"; do
    echo "$src_pod ---> $vip"
    kubectl exec $src_pod -- curl $vip  > /dev/null 2>&1
    success=$?
    if [ "$success" != "0" ]; then
        echo -e "\033[31mCurl from $src_pod to $vip failed \033[0m"
        let errors++
    fi
done

echo "Now trying to reach Kubernetes endpoint"
for src_pod in "${pods[@]}"; do
    echo "$src_pod ---> Kubernetes API"
    kubectl exec $src_pod -- kubectl get svc > /dev/null
    success=$?
    if [ "$success" != "0" ]; then
        echo -e "\033[31mAPI request from $src_pod failed \033[0m"
        let errors++
    fi
done

echo "Check that there is a floating IP reachable from the network node"
floatingIP=$(kubectl get svc kuryr-demo-service --no-headers -o custom-columns=":.status.loadBalancer.ingress[0].ip")
if [ "$floatingIP" == "" ]; then
  echo -e "\033[31mNo floating IP found \033[0m"
  exit 1
fi
echo "Found floating IP $floatingIP, trying to reach this from the network node"
ssh network "curl $floatingIP" > /dev/null 2>&1
success=$?
if [ "$success" != "0" ]; then
    echo -e "\033[31mCurl to floating IP $floatingIP failed \033[0m"
    let errors++
fi


if [ "$errors" -gt "0" ]; then  
    echo -e "\033[31mFound $errors errors \033[0m"
    exit 1
fi
echo "Done"



