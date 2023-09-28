#!/bin/bash

while true; do
    if ip net | grep -q ovnmeta; then
        iface_id=$(ip net e $(ip net | awk '/ovnmeta-/{ print $1 }' | head -n1) ip a | awk '/: tap/{ print $2 }' | tr -d ":" | cut -d @ -f 2 | tr -d "if")
        while [ "x$iface_id" == "x" ]; do
            echo "$(date): ovnmeta- namespace exists but didn't find the ovnmeta port yet, waiting" >> /tmp/screwer.log
            sleep 1
            iface_id=$(ip net e $(ip net | awk '/ovnmeta-/{ print $1 }' | head -n1) ip a | awk '/: tap/{ print $2 }' | tr -d ":" | cut -d @ -f 2 | tr -d "if")
        done
        iface=$(ip a | awk "/$iface_id: tap/{ print \$2 }" | cut -d @ -f1)
        ofport=$(ovs-vsctl get interface $iface ofport)
        flow=$(ovs-ofctl dump-flows br-int table=65 | grep "output:${ofport}$" | sed 's/.*\(cookie=0x[0-9a-f]*\), .*priority=[0-9]*,\([^ ]*\) actions.*/\1 \2/')
        if [ "x$flow" = "x" ]; then
            echo "$(date): tap device $iface is probably already screwed" >> /tmp/screwer.log
            exit 1
        fi
        cookie=$(echo $flow | cut -d \  -f 1)
        match=$(echo $flow | cut -d \  -f 2)
        ovs-ofctl mod-flows br-int table=65,$match,$cookie,actions=output:500
        echo "$(date): I screwed up tap device $iface" >> /tmp/screwer.log
        exit 0
    fi
    sleep 1
done
