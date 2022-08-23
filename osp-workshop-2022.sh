#!/bin/bash

WORKDIR=$(dirname "$0")
ANSIBLE_PLAYBOOK="ansible-playbook -i $inventory_file"
SCENARIO_NUM=5

inventory_file=$WORKDIR/tripleo-ansible-inventory.yaml
backup_name=backup
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

        scp $pass_key $undercloud:$remote_inventory_file $inventory_file

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


function backup() {
    check_and_get_inventory

#    $ANSIBLE_PLAYBOOK playbook.yml --tags backup -e workdir=$WORKDIR
}


function restore() {
    check_and_get_inventory
}


function prepare_scenario() {
    local scenario_number=$1

    check_and_get_inventory
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
  -i VALUE        relative path to local inventory file (default: $inventory_file)
  -f VALUE        relative path to tripleo ansible inventory file on the remote undercloud host (default: $remote_inventory_file)
  -p VALUE        private key to use for the ssh connection to the undercloud (default: user SSH key)
  -u VALUE        undercloud user and host (default: $undercloud)
  -h              display help

NOTE: ACTION must be last argument!
EOF

    exit 2
}


while getopts "b:f:i:p:u:h" opt_key; do
   case "$opt_key" in
       b)
           backup_name=$OPTARG
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
        backup
        ;;
    "restore")
        restore
        ;;
    *)
        usage
        ;;
esac
