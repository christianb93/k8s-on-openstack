#
# Check that the CSI node plugin is operating correctly on all nodes
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
# Go through nodes and, for each node, check that there is a matching CSI node 
# and that the node ID annotation has been added
#
nodes=$(kubectl get nodes  --no-headers -o custom-columns=":.metadata.name")
for node in $nodes; do
  annotation=$(kubectl get node $node -o json | jq -r '.metadata.annotations["csi.volume.kubernetes.io/nodeid"]')
  if [ "$annotation" != "null" ]; then
    echo "Found proper annotation $annotation"
  else
    echo "Could not find annotation on worker node $node"
  fi
  csiNode=$(kubectl get csinode $node --no-headers | wc -l)
  if [ "$csiNode" == "1" ]; then
    echo "Found CSI node for node $node"
  else
    echo "Could not find CSI node for node $node"
  fi
done 