#
# Test the Octavia Ingress controller
#

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
# Wait until all pods of a deployment are ready. 
# Parameters:
# $1 - the name of the deployment
#
function wait_for_deployment {
    expected=$(kubectl get deployment $1 --no-headers -o custom-columns=":.spec.replicas")
    count=0
    while [ $count != "$expected" ]; do
        sleep 2;
        count=$(kubectl get deployment $1 --no-headers -o custom-columns=":.status.availableReplicas")
    done
    return 0
}

#
# Create deployment
#
kubectl apply -f $scriptdir/test7.yaml
#
# and wait for pods to come up
#
wait_for_deployment "httpd"
wait_for_deployment "nginx"


echo "Waiting for loadbalancer"
lb_state="x"
attempts=0
while [ "$lb_state" != "ACTIVE" ]; do
    sleep 3;
    lb_state=$(openstack loadbalancer show kube_ingress_my-cluster_default_test-ingress -f value -c provisioning_status)
    let attemps++
    if [ "$attempts" -gt "32" ]; then 
      echo -e "\033[31mTimed out while waiting for load balancer \033[0m"
      exit 1
    fi
done

vip=$(openstack loadbalancer show kube_ingress_my-cluster_default_test-ingress -f value -c vip_address)

echo "Waiting for floating IP on vip $vip"
attempts=0
result=0
while [ "$result" != "1" ]; do
    sleep 1;
    result=$(openstack floating ip list --fixed-ip=$vip -f value -c ID | wc -l)
    let attemps++
    if [ "$attempts" -gt "32" ]; then 
      echo -e "\033[31mTimed out while waiting for floating ip \033[0m"
      exit 1
    fi
done

fip=$(openstack floating ip list --fixed-ip=$vip -f value -c "Floating IP Address")

echo "Trying to reach httpd service on floating IP $fip"
cmd="curl -s --header 'Host: apache.leftasexercise.org' http://$fip/index.html"
result=$(ssh network "$cmd" | grep 'It works' | wc -l)
if [ "$result" != "1" ]; then
  echo -e "\033[31mCurl to httpd service failed! \033[0m"
fi

echo "Trying to reach nginx service on floating IP $fip"
cmd="curl -s --header 'Host: nginx.leftasexercise.org' http://$fip/index.html"
result=$(ssh network "$cmd" | grep 'successfully installed' | wc -l)
if [ "$result" != "1" ]; then
  echo -e "\033[31mCurl to nginx service failed! \033[0m"
fi
