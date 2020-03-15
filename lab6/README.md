Running the lab
=================

As Kuryr requires a slightly different setup of the underlying OpenStack networks than usual, the usual scripts cannot be used to run this lab. Instead run

```
(cd gce ; terraform apply -auto-approve)
ansible-playbook gce/base.yaml
ansible-playbook gce/os.yaml
ansible-playbook -e "create_kuryr_networks=true" nodes/nodes.yaml
ansible-playbook -i .state/config/cluster.yaml lab6/cluster.yaml
```