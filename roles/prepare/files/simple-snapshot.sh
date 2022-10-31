#!/usr/bin/env bash

if ! which virsh >/dev/null 2>&1; then
    exit 0
fi

VIRSH="virsh"

action_snapshot()
{
    for i in  $($VIRSH list | awk '/^.*[0-9].*running/{print  $2}') ; do
        echo "=== Suspending $i";
        $VIRSH suspend $i
    done
    for i in  $($VIRSH list | awk '/^.*[0-9].*paused/{print  $2}') ; do
        if ! $VIRSH snapshot-list $i | grep $SNAP_STAGE_NAME; then
            echo Snapshoting $i
            $VIRSH snapshot-create-as $i --name $SNAP_STAGE_NAME;
        fi
    done
    for i in  $($VIRSH list | awk '/^.*[0-9].*paused/{print  $2}') ; do
        echo "=== Resuming $i";
        $VIRSH resume $i
    done
}

action_revert()
{
    for i in  $($VIRSH list | awk '/^.*[0-9].*running/{print  $2}') ; do
        echo "=== Suspending $i";
        $VIRSH suspend $i
    done
    for i in  $($VIRSH list | awk '/^.*[0-9].*paused/{print  $2}') ; do
        echo "=== Reverting $i to $SNAP_STAGE_NAME";
        $VIRSH snapshot-revert $i  --snapshotname $SNAP_STAGE_NAME
    done
    for i in  $($VIRSH list | awk '/^.*[0-9].*paused/{print  $2}') ; do
        echo "=== Resuming $i";
        $VIRSH resume $i
    done
}

action_delete()
{
    for i in  $($VIRSH list | awk '/^.*[0-9].*running/{print  $2}') ; do
        $VIRSH snapshot-delete $i --snapshotname $SNAP_STAGE_NAME
    done
}

action_delete_all()
{
    for i in $($VIRSH list --all --uuid) ; do
        local sl=$($VIRSH snapshot-list $i --name --leaves)
        while [ -n "$sl" ]; do
            for snap in $sl; do
                $VIRSH snapshot-delete $i --snapshotname $snap
            done
            sl=$($VIRSH snapshot-list $i --name --leaves | grep -v '^ *$' || echo '')
        done
    done
}


action_list()
{
    for i in  $($VIRSH list | awk '/^.*[0-9].*running/{print  $2}') ; do
        echo "List for $i"
        $VIRSH snapshot-list $i
    done
}

SNAP_STAGE_NAME="${2:-None}"

case $1 in
    snapshot)
        action_snapshot
        ;;
    revert)
        action_revert
        ;;
    delete)
        action_delete
        ;;
    delete_all)
        action_delete_all
        ;;
    *)
        action_list
        ;;
esac
