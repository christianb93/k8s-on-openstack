#
# Run a few tests to verify proper operations of the Keystone webhook server
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
# Get a token and use it to build a TokenReview object
#
token=$(openstack token issue -f value -c id)
tokenReview=$(cat << EOF
{
  "apiVersion": "authentication.k8s.io/v1beta1",
  "kind": "TokenReview",
  "metadata": {
      "name": "test-token"
  },
  "spec": {
      "token": "$token"
  }
}
EOF
)
echo $tokenReview | jq

#
# Verify that the Kubernetes API server can talk to the webhook server to
# authenticate the token
#
kubeserver=$(kubectl config view -o json | jq -r ".clusters[0].cluster.server")
echo "Using API server at $kubeserver"
result=$(curl -s -k  \
  --cert $statedir/k8s_certs/admin_client.crt \
  --key $statedir/k8s_certs/admin_client.rsa \
  -H "Content-Type: application/json" \
  -X POST \
  --data "$tokenReview" \
  $kubeserver/apis/authentication.k8s.io/v1beta1/tokenreviews)
check=$(echo $result | jq -r ".status.authenticated")
if [ "$check" != "true" ]; then
  echo -e "\033[31mRequest could not be authenticated, printing JSON structure \033[0m"
  echo $result | jq 
  exit 1
fi

echo "Successfully validated authentication via webhook"
