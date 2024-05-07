#!/bin/bash

WORKDIR=$(dirname "$0")
SCENARIO_NUM=$(ls -d $WORKDIR/roles/scenario* | sed 's/.*scenario\([0-9]*\)/\1/g' | sort | tail -n1)

ansible_params=""
backup_name=backup
private_key=""

WORKSHOP_MESSAGE_FILE=/tmp/workshop_message

function prepare_scenario() {
    check_and_get_inventory
    rm -f $WORKSHOP_MESSAGE_FILE

    echo "Preparing scenario $1 ... please wait."
    if [ "x$ansible_params" == "x-vv" ]; then
        $ansible_playbook $WORKDIR/playbooks/workarounds.yml
        $ansible_playbook $WORKDIR/playbooks/scenario.yml -e scenario=$1
        ansible_run_ecode=$?
    else
        $ansible_playbook $WORKDIR/playbooks/workarounds.yml
        $ansible_playbook $WORKDIR/playbooks/scenario.yml -e scenario=$1 > /dev/null
        ansible_run_ecode=$?
    fi

    if [ $ansible_run_ecode -eq 0 ]; then
        echo "Scenario $1 is ready."
    else
        echo "Scenario has failed!" >&2
        exit 3
    fi

    if [ -e $WORKSHOP_MESSAGE_FILE ]; then
        echo
        echo
        cat $WORKSHOP_MESSAGE_FILE
        echo
        echo
    fi
}
