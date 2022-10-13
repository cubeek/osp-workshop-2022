#!/bin/bash


WORKDIR=$(dirname "$0")
SCENARIO_NUM=5

ansible_params=""
inventory_file=$WORKDIR/tripleo-ansible-inventory.yaml
backup_name=backup
undercloud=stack@undercloud-0
remote_inventory_file=/home/stack/overcloud-deploy/overcloud/tripleo-ansible-inventory.yaml
private_key=""

WORKSHOP_MESSAGE_FILE=/tmp/workshop_message


function check_and_get_inventory() {
    if [ ! -e $inventory_file ]; then
        if [ "x$private_key" != "x" ]; then
            pass_key="-i $private_key"
        else
            pass_key=""
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

    $ansible_playbook $WORKDIR/playbooks/snapshot.yml -e backup_name=$backup_name -e snapshot_action=$1
}


function prepare_scenario() {
    check_and_get_inventory
    rm -f $WORKSHOP_MESSAGE_FILE

    $ansible_playbook $WORKDIR/playbooks/scenario.yml -t scenario$1

    echo
    echo
    [ -e $WORKSHOP_MESSAGE_FILE ] && cat $WORKSHOP_MESSAGE_FILE
    echo
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
ansible_playbook="ansible-playbook $ansible_params -i $inventory_file -e workdir=$WORKDIR -e workshop_message_file=$WORKSHOP_MESSAGE_FILE"

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
