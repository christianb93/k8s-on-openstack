#
# Check that the CSI node plugin is operating correctly on all nodes
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
# Go through nodes and, for each node, check that there is a matching CSI node 
# and that the node ID annotation has been added
#
nodes=$(kubectl get nodes  --no-headers -o custom-columns=":.metadata.name")
for node in $nodes; do
  annotation=$(kubectl get node $node -o json | jq -r '.metadata.annotations["csi.volume.kubernetes.io/nodeid"]')
  if [ "$annotation" != "null" ]; then
    echo "Found proper annotation $annotation"
  else
    echo -e "\033[31mCould not find annotation on worker node $node \033[0m"
  fi
  csiNode=$(kubectl get csinode $node --no-headers | wc -l)
  if [ "$csiNode" == "1" ]; then
    echo "Found CSI node for node $node"
  else
    echo -e "\033[31mCould not find CSI node for node $node \033[0m"
  fi
done 

#
# Now create a PVC
#
kubectl apply -f $scriptdir/cinder.yaml
#
# and wait until the PVC becomes visible
#
created=0
while [ "$created" == "0" ]; do
  created=$(kubectl get pvc | grep "csi-test" | wc -l)
  sleep 1
done 
#
# Now get the ID of the PVC and wait for the corresponding cinder volume
#
pvcID=$(kubectl get pvc csi-test --no-headers -o custom-columns=":metadata.uid")
volume="pvc-$pvcID"
echo "Waiting for Cinder volume $volume to be attached"
exists=0
while [ "$exists" == "0" ]; do
  exists=$(openstack volume list | grep "$volume" | wc -l)
done
#
# Wait until volume is in-use
#
status=$(openstack volume show $volume -c status -f value)
while [ "$status" != "in-use" ]; do
  status=$(openstack volume show $volume -c status -f value)
done
echo "Checking that volume is mounted into pod"
found=$(kubectl exec test6 ls | grep "csiVolume" | wc -l)
if [ "$found" == "1" ]; then
  echo "Success"
else
  echo -e "\033[31mCheck failed \033[0m"
fi