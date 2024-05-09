#!/bin/bash

source ./osp-workshop-common.sh

DATADIR="$WORKDIR/.data"

inventory_file=$DATADIR/edpm-inventory.yaml
kubeconfig_file=$HOME/.kube/config
oc_bin=oc
oc_namespace=openstack
inventory_secret_name=dataplanenodeset-openstack-edpm-ipam
compute_hosts_group_name=openstack-edpm-ipam

function usage {
    cat <<EOF
This version of the workshop script is designed to work with the RHOSO environment.

Usage: $(basename "$0") [OPTION] <ACTION>

ACTIONS:
  scenario VALUE  prepare scenario number VALUE, can be 1-$SCENARIO_NUM
  backup          backup virtual environment
  restore         restore virtual environment

OPTIONS:
  -b VALUE        name for the backup (default: $backup_name)
  -d              turn on debug for ansible
  -i VALUE        relative path to local inventory file (default: $inventory_file)
  -p VALUE        private key to use for the ssh connection to the edpm nodes (default: user SSH key)
  -c VALUE        absolute path to the kubeconfig file (default: $kubeconfig_file)
  -o VALUE        absolute path to the oc binary (default: oc needs to be in the one of the locations from the PATH variable)
  -n VALUE        name of the OpenShift namespace where RHOSO is installed (default: $oc_namespace)
  -f VALUE        name of the OpenShift secret where EDPM inventory is stored (default: $inventory_secret_name)
  -K              tell ansible to ask for the sudo password (--ask-become-pass option in ansible)
  -h              display help

NOTE: ACTION must be the last argument!
EOF

    exit 2
}

function check_and_get_inventory() {
    if [ ! -e $inventory_file ]; then
        if [ ! -d $DATADIR ]; then
            mkdir -p $DATADIR
        fi
        $oc_bin --kubeconfig $kubeconfig_file -n $oc_namespace get secret $inventory_secret_name -o json | jq '.data | map_values(@base64d)' | jq -r '.inventory' > $inventory_file
        if [ $? -ne 0 ]; then
            echo
            cat << EOF
Error while trying to get inventory from the OpenShift. Please make sure that there is 'oc' binary available,
there is proper $kubeconfig_file provided and that OpenStack DataPlane is installed in the $oc_namespace.
EOF
            exit 1
        fi
        # Now lets remove from the inventory file lines about ssh ke in the
        # /runner/env location as this is where key is mounted in the ansible
        # runner pod but we want to use key provided with the -p parameter
        # instead
        sed -i '/ansible_ssh_private_key_file: \/runner/d' $inventory_file
    fi
}

while getopts "b:dKf:i:p:c:o:u:n" opt_key; do
    case "$opt_key" in
       b)
           backup_name=$OPTARG
           ;;
       d)
           ansible_params="$ansible_params -vvvv"
           debug=true
           ;;
       f)
           inventory_secret_name=$OPTARG
           ;;
       i)
           inventory_file=$OPTARG
           ;;
       p)
           private_key=$OPTARG
           ansible_params="$ansible_params --private-key $private_key"
           ;;
       c)
           kubeconfig_file=$OPTARG
           ;;
       o)
           oc_bin=$OPTARG
           ;;
       n)
           oc_namespace=$OPTARG
           ;;
       K)
           ansible_params="$ansible_params --ask-become-pass"
           ;;
       h|*)
           usage
           ;;
   esac
done

# This needs to be defined aftar parsing parameters because of variables passed
ansible_playbook="ansible-playbook $ansible_params -i $inventory_file -e compute_group_name=$compute_hosts_group_name -e installer=podified -e working_dir=$DATADIR -e workshop_message_file=$WORKSHOP_MESSAGE_FILE -e oc_bin=$oc_bin -e oc_namespace=$oc_namespace -e create_env_file=$DATADIR/create_env.sh"

shift $((OPTIND-1))

if [ "x$1" == "x" ]; then
    echo "Missing action!"
    echo
    usage
fi

case "$1" in
    "scenario")
        if [ "x$2" == "x" ]; then
            echo "Missing scenario number!"
            echo
            usage
        fi
        if [ $2 -lt 1 -o $2 -gt $SCENARIO_NUM ]; then
            echo "Wrong scenario number!"
            echo
            usage
        fi
        prepare_scenario $2
        ;;
    "backup")
        # The backup action is called snapshot
        do_snapshot snapshot
        ;;
    "restore")
        do_snapshot revert
        ;;
    *)
        usage
        ;;
esac
