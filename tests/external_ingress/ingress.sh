#
# Test the external NGINX ingress controller
#

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
kubectl apply -f $scriptdir/ingress.yaml
#
# and wait for pods to come up
#
wait_for_deployment "httpd"
wait_for_deployment "nginx"

#
# Wait until the loadbalancer status is updated in the ingress
#
echo "Waiting for IP in ingress status"
ip="null"
while [ "$ip" == "null" ]; do
  ip=$(kubectl get ingress  test-ingress -o json  | jq -r ".status.loadBalancer.ingress[0].ip")
  sleep 2
  echo "Still waiting..."
done


echo "Trying to reach httpd service"
result=$(curl -s --header 'Host: apache.leftasexercise.org' http://$ip:8080/index.html | grep 'It works' | wc -l)
if [ "$result" != "1" ]; then
  echo -e "\033[31mCurl to httpd service failed! \033[0m"
fi

echo "Trying to reach nginx service"
result=$(curl -s --header 'Host: nginx.leftasexercise.org' http://$ip:8080/index.html | grep 'successfully installed' | wc -l)
if [ "$result" != "1" ]; then
  echo -e "\033[31mCurl to nginx service failed! \033[0m"
fi
