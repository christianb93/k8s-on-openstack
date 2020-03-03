Running the lab
=================

As Kuryr requires a slightly different setup of the underlying OpenStack networks than usual, the *site.yaml* script cannot be used to run this lab. Instead run

```
(cd base ; terraform apply -auto-approve)
ansible-playbook base/base.yaml
ansible-playbook os/os.yaml
ansible-playbook -e "create_kuryr_networks=true" nodes/nodes.yaml
ansible-playbook -i .state/config/cluster.yaml lab6/cluster.yaml
```