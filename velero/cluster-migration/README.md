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

**Note:** SRC_KUBECONFIG and DEST_KUBECONFIG do not necessarily need to be separate files.

## Installation

Install minio on the Source cluster and velero on the Source and Destination clusters:
```bash
make install
```

Validate that the Destination cluster can talk to Minio via NodePort
```bash
make check_comms
make get_backup_location
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

Restore an entire backup to the Destination Cluster:
```bash
BACKUP_NAME=a_backup_name make restore_all
```

**Optional:** Instead of restoring an entire backup, you can also restore individual apps. In order
to do so, edit the Makefile and add your app(s) labels one line at a time to `APP_LABELS`.
After `APP_LABELS` is updated, you can restore them all individually to the Destination Cluster:
```bash
BACKUP_NAME=a_backup_name make restore_only_apps
```

Get restores:
```bash
make get_restores
```

Look at a restore's logs:
```bash
RESTORE_NAME=a_restore_name make get_restore
```

**Note:** On the restore logs above, it is common to see innocuous Warnings like the ones below. Velero is smart
enough not to overwrite any resources in the destination of the same name. These can be ignored.

```
Warnings:
  Velero:     <none>
  Cluster:  could not restore, CustomResourceDefinition "alertmanagerconfigs.monitoring.coreos.com" already exists. Warning: the in-cluster version is different than the backed-up version.
            could not restore, CustomResourceDefinition "alertmanagers.monitoring.coreos.com" already exists. Warning: the in-cluster version is different than the backed-up version.
            could not restore, CustomResourceDefinition "backups.velero.io" already exists. Warning: the in-cluster version is different than the backed-up version.
            could not restore, CustomResourceDefinition "backupstoragelocations.velero.io" already exists. Warning: the in-cluster version is different than the backed-up version.
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

## Troubleshooting

Occasionally, you may see an error like this when querying a backup or a restore:
```
Warnings:   <error getting warnings: Get "http://10.0.1.7:30673/velero/restores/dest-cluster-2022-03-22-1647977109/restore-dest-cluster-2022-03-22-1647977109-results.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=xxx": dial tcp 10.0.1.7:30673: i/o timeout>

Errors:  <error getting errors: Get "http://10.0.1.7:30673/velero/restores/dest-cluster-2022-03-22-1647977109/restore-dest-cluster-2022-03-22-1647977109-results.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=xxx": dial tcp 10.0.1.7:30673: i/o timeout>
```

If `make check_comms` succeeds without reporting any errors, this means that communication between
clusters is OK, but your local workstation cannot communicate over TCP/IP to the minio NodePort on
the destination cluster.

To resolve this you can simply add the NodeIP to your workstation's primary interface and use kubectl proxy to forward.

For example, the following commands resolve the error above:
```bash
[jmiller@euclid: ~/Projects/storage/velero/cluster-migration] [master|✚ 2] ✘-INT
15:39 $ sudo ip addr add 10.0.1.7/32 dev enp0s31f6
[jmiller@euclid: ~/Projects/storage/velero/cluster-migration] [master|✚ 2] ✔
15:39 $ ping 10.0.1.7
PING 10.0.1.7 (10.0.1.7) 56(84) bytes of data.
64 bytes from 10.0.1.7: icmp_seq=1 ttl=64 time=0.049 ms
64 bytes from 10.0.1.7: icmp_seq=2 ttl=64 time=0.039 ms
^C
--- 10.0.1.7 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1009ms
rtt min/avg/max/mdev = 0.039/0.044/0.049/0.005 ms
[jmiller@euclid: ~/Projects/storage/velero/cluster-migration] [master|✚ 2] ✔
15:40 $ kubectl port-forward --address localhost,10.0.1.7 service/minio 30673:9000 -n minio --kubeconfig ~/Downloads/test-azure-2.yaml
Forwarding from 10.0.1.7:30673 -> 9000
Forwarding from 127.0.0.1:30673 -> 9000
Forwarding from [::1]:30673 -> 9000
Handling connection for 30673
Handling connection for 30673
^C
```

To delete the IP you added run:
```bash
sudo ip addr del 10.0.1.7/32 dev enp0s31f6
``
