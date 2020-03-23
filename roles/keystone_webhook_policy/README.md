keystone_webhook_policy
===========================

This role builds a config map with a pre-configured policy as expected by the Keystone webhook server.

The following variables need to be set to run this role.

* policy_config_map_name - the name of the config map, which will be created in the kube-system namespace


