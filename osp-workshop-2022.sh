#!/bin/bash

WORKDIR=$(dirname "$0")
inventory_file=$WORKDIR/tripleo-ansible-inventory.yaml
ANSIBLE_PLAYBOOK="ansible-playbook -i $inventory_file"
DEFAULT_BACKUP_NAME=backup

undercloud=stack@undercloud-0
remote_inventory_file=tripleo-ansible-inventory.yaml
private_key=""


function check_and_get_inventory() {
    if [ ! -e $inventory_file ]; then
        if [ "x$private_key" != "x" ]; then
            pass_key="-i $private_key"
        else
            pass_key=""
        fi

        echo "scp $pass_key $undercloud:$remote_inventory_file $inventory_file"

        if [ $? -ne 0 ]; then
            cat << EOF
The script requires working ssh connection to stack@undercloud-0.
The host and private key can be configured, please see help (-h)
for more information.
EOF
        fi
    fi
}


function backup() {
    local backup_name=$1

    check_and_get_inventory

    echo "calling backup to $backup_name"
}


function restore() {
    local backup_name=$1

    check_and_get_inventory

    echo "calling restore from $backup_name"
}


function prepare_scenario() {
    local scenario_number=$1

    check_and_get_inventory

    echo "preparing scenario $scenario_number"
}


function usage {
    cat <<EOF
Usage: $(basename "$0") [OPTION]
  -b VALUE    backup environment from VALUE (default: $DEFAULT_BACKUP_NAME)
  -i VALUE    relative path to local inventory file (default: $inventory_file)
  -f VALUE    relative path to tripleo ansible inventory file on the remote undercloud host (default: $remote_inventory_file)
  -p VALUE    private key to use for the ssh connection to the undercloud
  -r VALUE    restore environment from the VALUE backup (default: $DEFAULT_BACKUP_NAME)
  -s VALUE    prepare scenario based on VALUE number
  -u VALUE    undercloud user and host (default: $undercloud)
  -h          display help
EOF

    exit 2
}


while getopts "b:f:i:p:r:s:u:h" opt_key; do
   case "$opt_key" in
       b)
           backup $OPTARG
           ;;
       f)
           remote_inventory_file=$OPTARG
           ;;
       i)
           inventory_file=$OPTARG
           ;;
       p)
           private_key=$OPTARG
           ;;
       r)
           restore $OPTARG
           ;;
       s)
           prepare_scenario $OPTARG
           ;;
       u)
           undercloud=$OPTARG
           ;;
       h|*)
           usage
           ;;
   esac
done

if [ $OPTIND -eq 1 ]; then
    usage
fi
