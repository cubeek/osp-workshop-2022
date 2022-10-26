#!/bin/bash

alias virsh="podman exec nova_virtlogd virsh"

while true; do
    if podman exec nova_virtlogd virsh list --all | grep -q paused; then
        for domain in $(podman exec nova_virtlogd virsh list --all | awk '/paused/{ print $2 }'); do
            podman exec nova_virtlogd virsh reset $domain
            podman exec nova_virtlogd virsh resume $domain
        done
    fi
    sleep 1
done
