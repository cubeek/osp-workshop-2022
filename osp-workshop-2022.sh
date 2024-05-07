#!/bin/bash


inventory_file=$WORKDIR/tripleo-ansible-inventory.yaml
undercloud=stack@undercloud-0
remote_inventory_file=/home/stack/overcloud-deploy/overcloud/tripleo-ansible-inventory.yaml

function check_and_get_inventory() {
    if [ ! -e $inventory_file ]; then
        if [ "x$private_key" != "x" ]; then
            pass_key="-i $private_key"
        else
            pass_key=""
        fi

        ssh $pass_key $undercloud ls $remote_inventory_file > /dev/null 2> /dev/null

        if [ $? -ne 0 ]; then
            ssh $pass_key $undercloud "source stackrc && /usr/bin/tripleo-ansible-inventory --static-yaml-inventory $remote_inventory_file" > /dev/null 2> /dev/null
        fi

        scp $pass_key $undercloud:$remote_inventory_file $inventory_file

        # Fix stupid TripleO
        undercloud_ip=$(awk '/undercloud/{ print $1 }' /etc/hosts)
        sed -i "s/ansible_host: localhost/ansible_host: $undercloud_ip/" $inventory_file
        sed -i "/ansible_connection: local/d" $inventory_file

        if [ $? -ne 0 ]; then
            echo
            cat << EOF
The script requires working ssh connection to stack@undercloud-0.
The host and private key can be configured, please see help (-h)
for more information.
EOF
        exit 1
        fi
    fi
}


function do_snapshot() {
    check_and_get_inventory
    set -e

    $ansible_playbook $WORKDIR/playbooks/snapshot.yml -e backup_name=$backup_name -e snapshot_action=$1

    echo
    # Check that everything is fine
    if virsh list --all | tail -n+3 | grep -q paused; then
        echo "Some VMs got stuck in paused state, trying to fix it ..." 1>&2
        for vm in $(virsh list --all | awk '/paused/{ print $ 2}'); do
            virsh reset $vm
            virsh resume $vm
        done

        if virsh list --all | tail -n+3 | head -n-1 | grep -v running | grep -q "-"; then
            echo "Unable to resume some VMs, check libvirt" 1>&2
            exit 2
        fi

    fi

    $ansible_playbook $WORKDIR/playbooks/sync.yml

    echo "$1 operation using backup name $backup_name was successful"
}




function usage {
    cat <<EOF
Usage: $(basename "$0") [OPTION] <ACTION>

ACTIONS:
  scenario VALUE  prepare scenario number VALUE, can be 1-$SCENARIO_NUM
  backup          backup virtual environment
  restore         restore virtual environment

OPTIONS:
  -b VALUE        name for the backup (default: $backup_name)
  -d              turn on debug for ansible
  -i VALUE        relative path to local inventory file (default: $inventory_file)
  -f VALUE        relative path to tripleo ansible inventory file on the remote undercloud host (default: $remote_inventory_file)
  -p VALUE        private key to use for the ssh connection to the undercloud (default: user SSH key)
  -u VALUE        undercloud user and host (default: $undercloud)
  -h              display help

NOTE: ACTION must be the last argument!
EOF

    exit 2
}


while getopts "b:df:i:p:u:h" opt_key; do
   case "$opt_key" in
       b)
           backup_name=$OPTARG
           ;;
       d)
           ansible_params=-vv
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
       u)
           undercloud=$OPTARG
           ;;
       h|*)
           usage
           ;;
   esac
done

# This needs to be defined aftar parsing parameters because of variables passed
ansible_playbook="ansible-playbook $ansible_params -i $inventory_file -e installer=tripleo -e workdir=$WORKDIR -e workshop_message_file=$WORKSHOP_MESSAGE_FILE"

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
