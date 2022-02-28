# Cluster to Cluster Data Migration

This guide and automation will help you migrate all data from one K8s cluster to another using
velero backup and restore.

The cluster from which the backup is taken will be referred to as "Source". The "Destination" will be the cluster
where the data will be restored.

## Pre-requisites

Linux or MacOS (workstation) node with:
1. `kubectl`,`make`,`tar`,`curl`,`gettext` pkg (for envsubst) and `git` installed
1. kubeconfig files for both Source and Destination clusters (files can be either separate or merged)
1. access to the K8S API of both Source and Destination clusters to run `kubectl` commands

A Platform9 Managed Kubernetes cluster with same K8s version as Source cluster for data migration. This
cluster would be as identical as possible as the Source cluster.

## Setup

On the workstation node clone down this repo:
```bash
git clone https://github.com/Platform9-Community/storage.git pf9-velero
cd pf9-velero/velero/cluster-migration
export PATH=$PATH:$(pwd)
```

Ensure the pre-requisites are met:
```bash
make check
```

Edit the Makefile and customize the K8s Source and Destination variables at the top of the file.
```
## YOU MUST CUSTOMIZE THESE
##
SRC_KUBECONFIG = /home/jmiller/Downloads/source-cluster.yaml
SRC_KUBE_CONTEXT = default
DEST_KUBECONFIG = /home/jmiller/Downloads/destination-cluster.yaml
DEST_KUBE_CONTEXT = default
```

## Installation

Install minio on the Source cluster and velero on the Source and Destination clusters:
```bash
make install
```

Validate that the Destination cluster can talk to Minio via NodePort
```bash
make check_comms
```

## Backup and Restore

Create a new backup of the Source cluster:
```bash
make backup
```

List backups:
```bash
make get_backups
```

Look at a backup's logs:
```bash
BACKUP_NAME=a_backup_name make get_backup
```

Restore a backup to the Destination Cluster:
```bash
BACKUP_NAME=a_backup_name make restore
```

Get restores:
```bash
make get_restores
```

Look at a restore's logs:
```bash
RESTORE_NAME=a_restore_name make get_restore
```


## Additional Options

Uninstall minio and velero from both Source and Destination clusters:
```bash
make clean
```

Uninstall velero from Source cluster
```bash
TARGET=source make uninstall_velero
```

Uninstall velero from Destination cluster
```bash
TARGET=dest make uninstall_velero
```

Install/Re-install Minio
```bash
make uninstall_minio
make minio
```

Install/Re-install velero CLI (perhaps changing VELERO_CLIENT_VERSION in the Makefile)
```bash
rm velero
make velero
```
