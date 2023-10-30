#!/bin/bash

function get_metadata_port_iface_id() {
    ip net e $(ip net | awk '/ovnmeta-/{ print $1 }' | head -n1) ip a | awk '/: tap/{ print $2 }' | tr -d ":" | cut -d @ -f 2 | tr -d "if"
}


function get_iface_ofport() {
    local iface=$1

    ovs-vsctl get interface $iface ofport
}


function log_message() {
    echo "$(date): $1" >> /tmp/screwer.log
}


while true; do
    if ip net | grep -q ovnmeta; then
        iface_id=$(get_metadata_port_iface_id)
        while [ "x$iface_id" == "x" ]; do
            log_message "ovnmeta- namespace exists but didn't find the ovnmeta port yet, waiting"
            sleep 1
            iface_id=$(get_metadata_port_iface_id)
        done
        iface=$(ip a | awk "/$iface_id: tap/{ print \$2 }" | cut -d @ -f1)
        ofport=$(get_iface_ofport $iface)
        while [ "x$ofport" == "x" ]; do
            log_message "The $iface device is not yet in OVS"
            sleep 1
            ofport=$(get_iface_ofport $iface)
        done
        flow=$(ovs-ofctl dump-flows br-int table=65 | grep "output:${ofport}$" | sed 's/.*\(cookie=0x[0-9a-f]*\), .*priority=[0-9]*,\([^ ]*\) actions.*/\1 \2/')
        if [ "x$flow" = "x" ]; then
            log_message "tap device $iface is probably already screwed"
            exit 1
        fi
        cookie=$(echo $flow | cut -d \  -f 1)
        match=$(echo $flow | cut -d \  -f 2)
        ovs-ofctl mod-flows br-int table=65,$match,$cookie,actions=output:500
        log_message "I screwed up tap device $iface"
        exit 0
    fi
    sleep 1
done
