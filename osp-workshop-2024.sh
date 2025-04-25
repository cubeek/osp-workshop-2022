#!/bin/bash

WORKDIR=$(dirname "$0")
source $WORKDIR/osp-workshop-common
    DATADIR="/tmp/ovn_training/data"

DEFAULT_INVENTORY_FILE=$DATADIR/edpm-inventory.yaml
DEFAULT_KUBECONFIG_FILE=$HOME/.kube/config
DEFAULT_OC_NAMESPACE=openstack
DEFAULT_INVENTORY_SECRET_NAME=dataplanenodeset-openstack-edpm-ipam
DEFAULT_OPENSTACK_CONTROL_PLANE_CR_NAME="openstack-control-plane"

DATAPLANE_SSH_KEY_SECRET_NAME="dataplane-ansible-ssh-private-key-secret"
SSH_CONFIG=$HOME/.ssh/config
PHYSNET_NIC=ens4
PROJECT_NET_PHYSNET="datacentre"
NIC_MAPPINGS="$PROJECT_NET_PHYSNET: $PHYSNET_NIC"

# Configuration of the public subnet when running in the RH Trainings lab
OSP_SUBNET=192.168.51.0/24
OSP_GW_IP=192.168.51.254
OSP_ALLOCATION_START=192.168.51.151
OSP_ALLOCATION_END=192.168.51.199
UTILITY_IP=172.25.250.253

inventory_file=$DEFAULT_INVENTORY_FILE
kubeconfig_file=$DEFAULT_KUBECONFIG_FILE
oc_bin=oc
oc_namespace=$DEFAULT_OC_NAMESPACE
inventory_secret_name=$DEFAULT_INVENTORY_SECRET_NAME
compute_hosts_group_name=openstack-edpm-ipam
openstack_control_plane_cr_name=$DEFAULT_OPENSTACK_CONTROL_PLANE_CR_NAME

function usage {
    cat <<EOF
This version of the workshop script is designed to work with the RHOSO environment.

Usage: $(basename "$0") [OPTION] <ACTION>

ACTIONS:
  scenario VALUE  prepare scenario number VALUE, can be 1-$SCENARIO_NUM
  backup          backup virtual environment
  restore         restore virtual environment

OPTIONS:
  -b VALUE        name for the backup (default: $DEFAULT_BACKUP_NAME)
  -d              turn on debug for ansible
  -i VALUE        relative path to local inventory file (default: $DEFAULT_INVENTORY_FILE)
  -p VALUE        private key to use for the ssh connection to the edpm nodes (default: user SSH key)
  -c VALUE        absolute path to the kubeconfig file (default: $DEFAULT_KUBECONFIG_FILE)
  -o VALUE        absolute path to the oc binary (default: oc needs to be in the one of the locations from the PATH variable)
  -n VALUE        name of the OpenShift namespace where RHOSO is installed (default: $DEFAULT_OC_NAMESPACE)
  -s VALUE        name of the OpenShift secret where EDPM inventory is stored (default: $DEFAULT_INVENTORY_SECRET_NAME)
  -r VALUE        name of the OpenStackControlPlane CR created in OpenShift (default: $DEFAULT_OPENSTACK_CONTROL_PLANE_CR_NAME)
  -K              tell ansible to ask for the sudo password (--ask-become-pass option in ansible)
  -j VALUE        SSH jump host which will be used to access to the EDPM nodes by ansible; if set it will be configured in the $SSH_CONFIG file
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
        tmp_edpm_inventory_file=$(mktemp)
        $oc_bin --kubeconfig $kubeconfig_file -n $oc_namespace get secret $inventory_secret_name -o json | jq '.data | map_values(@base64d)' | jq -r '.inventory' > $tmp_edpm_inventory_file
        if [ $? -ne 0 ]; then
            echo
            cat << EOF
Error while trying to get inventory from the OpenShift. Please make sure that there is 'oc' binary available,
there is proper $kubeconfig_file provided and that at least one OpenStack DataPlaneNodeSet is installed in the $oc_namespace.

EOF
            exit 1
        fi
       # Now lets build very simple inventory file with just required options
       python3 prepare_inventory.py $tmp_edpm_inventory_file $inventory_file
    fi
}

function configure_ssh_jump_host() {
    local jump_host=$1
    if grep -q "ProxyJump $jump_host" $SSH_CONFIG; then
        return
    fi
    for hostname in $(grep ansible_host $inventory_file | awk -F':' '{print $2}'); do
        cat <<EOF >>$SSH_CONFIG
Host $hostname
    ProxyJump $jump_host
EOF
    done

    # We also need to make sure that the known_hosts file is empty otherwise
    # when the env was stoped and then started again ssh to the compute
    # nodes through the jump host will not be possible
    rm $SSH_KNOWN_HOSTS
}

function ensure_nic_mappings_are_set() {
    $oc_bin -n $oc_namespace patch openstackcontrolplane $openstack_control_plane_cr_name --type=merge -p "
spec:
  ovn:
   template:
     ovnController:
       nicMappings:
         $NIC_MAPPINGS
"
    $OC_BIN -n $OC_NAMESPACE wait --for=consition=Ready openstackcontrolplane/$openstack_control_plane_cr_name --timeout=60s
}

function ensure_private_key_exists() {
    local key_file=$1
    local tempdir=$(mktemp -d)
    if [ ! -e $key_file ]; then
        $oc_bin --kubeconfig $kubeconfig_file -n $oc_namespace extract secret/$DATAPLANE_SSH_KEY_SECRET_NAME --keys=ssh-privatekey --to=$tempdir
       mv $tempdir/ssh-privatekey $key_file
    fi
    # Add private key to the ssh-agent
    eval $(ssh-agent)
    ssh-add $key_file
}

function is_rh_training_lab() {
    # Returns 0 is hostname is "workstation" and username is "student" as with
    # that we can assume that it runs on the Red Hat Trainings Lab environment
    is_rh_training_lab=1
    [[ $(hostname) == "workstation" && $(whoami) == "student" ]] && is_rh_training_lab=0

    return $is_rh_training_lab
}


function configure_routing_to_osp_ext_net() {
    local osp_subnet=$1
    local utility_ip=$2
    local nic=$(/sbin/ip -o route get $utility_ip | awk '{print $3}')
    sudo /sbin/ip route add $osp_subnet via $utility_ip dev $nic
}

while getopts "b:dKs:i:p:c:o:n:j:r:" opt_key; do
    case "$opt_key" in
       b)
           backup_name=$OPTARG
           ;;
       d)
           ansible_params="$ansible_params -vv"
           debug=true
           ;;
       s)
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
       j)
          jump_host=$OPTARG
          ;;
       r)
          openstack_control_plane_cr_name=$OPTARG
          ;;
       h|*)
           usage
           ;;
   esac
done

# This needs to be defined after parsing parameters because of variables passed
ansible_playbook="ansible-playbook $ansible_params \
    -i $inventory_file \
    -e compute_group_name=$compute_hosts_group_name \
    -e installer=podified \
    -e working_dir=$DATADIR \
    -e workshop_message_file=$WORKSHOP_MESSAGE_FILE \
    -e oc_bin=$oc_bin \
    -e oc_namespace=$oc_namespace \
    -e create_env_file=$DATADIR/create_env.sh "

# If script is unning in the RH Training labs (it assumes that if
# user is "student", hostname is "workstation" then it runs in the training
# lab), then we need to add additional route to the "External network" and
# configure proper subnet for the OSP external network
if is_rh_training_lab; then
    configure_routing_to_osp_ext_net $OSP_SUBNET $UTILITY_IP
    ansible_playbook="$ansible_playbook \
        -e public_network_gw_ip=$OSP_GW_IP \
        -e public_network_subnet_range=$OSP_SUBNET \
        -e public_network_ip_allocation_start=$OSP_ALLOCATION_START \
        -e public_network_ip_allocation_end=$OSP_ALLOCATION_END "
fi

shift $((OPTIND-1))
main $1 $2
