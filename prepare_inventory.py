#!/bin/env python3

# This is simple script which converts EDPM inventory from the OpenShift's secret
# to the very simple inventory file which can be used by the RHOSO break/fix training
# scripts while preparing training scenarios.
# Usage of the script:
# python3 prepare_inventory.py <path_to_the_edpm_inventory.yaml> <path_to_the_output_file.yaml>
#
# Edpm inventory file can be get from the OpenShift with command like:
#
# oc get secret <secret_name> -o json | jq '.data | map_values(@base64d)' | jq -r '.inventory'


import yaml
import sys


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Path to the yaml file with the RHOSO edpm inventory is "
              "required to be passed as first argument and output file "
              "path is required to be passed as second argument to this "
              "script.")
        sys.exit(1)

    src_file = sys.argv[1]
    dst_file = sys.argv[2]
    if not src_file:
        print("Yaml file with the RHOSO edpm inventory is required "
              "to be passed as first argument.")
        sys.exit(1)
    if not dst_file:
        print("Output file is required to be passed as second argument.")
        sys.exit(1)

    with open(src_file) as src:
        edpm_inventory = yaml.safe_load(src)

    dest_inventory = {}
    for group_name, group in edpm_inventory.items():
        dest_inventory.setdefault(group_name, {'hosts': {}})
        for hostname, host_options in group.get('hosts').items():
            canonical_hostname = host_options.get('canonical_hostname')
            ext_ip = host_options.get('external_ip')
            ansible_host = canonical_hostname or ext_ip or \
                    host_options.get('ansible_host')
            dest_inventory[group_name]['hosts'][hostname] = {
                'ansible_user': host_options.get('ansible_user'),
                'ansible_host': ansible_host
            }

    with open(dst_file, 'w') as dst:
        yaml.dump(dest_inventory, dst, default_flow_style=False)
