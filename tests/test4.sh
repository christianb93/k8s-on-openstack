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
statedir=$scriptdir/../.state

#
# Get credentials
#
source $statedir/credentials/k8s-openrc
export KUBECONFIG=$statedir/config/admin-kubeconfig

#
# Create deployment
#
kubectl apply -f $scriptdir/test4.yaml
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




