# osp-workshop-2022
This is a repository to obtain scenarios for the OSP Workshop. The
description of what each scenario breaks can be found in SCENARIOS.txt file.
It's recommended to use virtualized environment because of use of libvirt
snapshots to restore the functionality. It's also possible to use real environment
but keep in mind scenarios break things and then it's up to you
to fix it because snapshotting won't work.

## Installation and usage

To run any of the break/fix scenarios in this repo you need to:

- clone repository

```
$ mkdir osp_training
$ cd osp_training
$ git clone https://github.com/cubeek/osp-workshop-2022.git scenarios_repo
$ cd scenarios_repo
```

- prepare inventory file for Ansible:

```
$ bash osp-workshop-2024.sh -s dataplanenodeset-openstack-data-plane -c ~/.auth/ocp4-kubeconfig inventory
```

- now You can run scenarios with command like:

```
$ ./lab start bfx019
```
