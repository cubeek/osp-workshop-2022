#!/bin/bash

ANSIBLE_PLAYBOOK="ansible-playbook -i inventory"


function backup() {
    local backup_name=$1

    echo "calling backup to $backup_name"
#    $ANSIBLE_PLAYBOOK backup.yml -e backup_name=$backup_name
}


function restore() {
    local backup_name=$1

    echo "calling restore from $backup_name"
}


function prepare_scenario() {
    local scenario_number=$1

    echo "preparing scenario $scenario_number"
}


function usage {
    cat <<EOM
Usage: $(basename "$0") [OPTION]...
  -b VALUE    backup environment from VALUE
  -i VALUE    set inventory file to VALUE
  -s VALUE    prepare scenario based on VALUE number
  -r VALUE    restore environment from the VALUE backup
  -h          display help
EOM

    exit 2
}

inventory_file=$(find $HOME -name tripleo-ansible-inventory.yaml | head -n1)

while getopts "b:r:s:i:h" opt_key; do
   case "$opt_key" in
       b)
           backup $OPTARG
           ;;
       i)
           inventory_file=$OPTARG
           ;;
       r)
           restore $OPTARG
           ;;
       s)
           prepare_scenario $OPTARG
           ;;
       h|*)
           usage
           ;;
   esac
done

if [ $OPTIND -eq 1 ]; then
    usage
fi
