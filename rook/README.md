# CSI with Rook and Ceph on Platform9 Managed Kubernetes Freedom Plan
Rook turns distributed storage systems into self-managing, self-scaling, self-healing storage services. It automates the tasks such as deployment, configuration, scaling, upgrading, monitoring, resource management for the distributed storage like Ceph on top of Kubernetes. It has support for multiple storage providers like Ceph, EdgeFS, CockroachDB etc. ceph being the favourite one.

# Prerequisites:
We have tested Rook with following configuration on the cluster:
1. Platform9 Freedom Plan (a free tier account is required) with three worker nodes and one Master node
2. Each worker node should have at least one free unformatted disk of size 10GiB attached to it.
3. Metallb loadbalancer configured on bare metal cluster for enabling optional dashboard.
4. Flannel or Calico for CNI.
5. Worker node size: 2VPUs x 8GB Memory (4VPU x 16GB recommended)
6. Master node size: 2VCPU x 8GB Memory (4VPU x 16GB recommended)
7. 'lvm2' is required on Ubuntu 16.04. Ubuntu 18.04 comes pre installed with lvm2.

# Note:
There may be additional prerequisites for CentOS.
The deployment will work with any platform9 plans.

# Deploying the rook v1.4.6 with internal ceph on kubernetes:

Clone the Kool Kubernetes repository on any machine from where the kubectl can deploy json manifests to your kubernetes cluster.

```bash
$ git clone https://github.com/KoolKubernetes/csi.git
```

Deploy yamls in following order:
```bash
$ kubectl apply -f csi/rook/internal-ceph/1.4.6/1-common.yaml
```

Deploy the second yaml for rook operator
```bash
$ kubectl apply -f csi/rook/internal-ceph/1.4.6/2-operator.yaml
configmap/rook-ceph-operator-config created
deployment.apps/rook-ceph-operator created
```

Verify the rook pods are running before proceeding with next deployment yaml.
```bash
$ k get all -n rook-ceph
NAME                                      READY   STATUS    RESTARTS   AGE
pod/rook-ceph-operator-848b8bc676-bdhc6   1/1     Running   0          64m
pod/rook-discover-7w89l                   1/1     Running   0          64m
pod/rook-discover-cm5vm                   1/1     Running   0          64m
pod/rook-discover-lddn2                   1/1     Running   0          64m



NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/rook-discover   3         3         3       3            3           <none>          64m

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/rook-ceph-operator   1/1     1            1           64m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/rook-ceph-operator-848b8bc676   1         1         1       64m
```


Deploy third yaml to create the ceph cluster.
```bash
$ kubectl apply -f csi/rook/internal-ceph/1.4.6/3-cluster.yaml
cephcluster.ceph.rook.io/rook-ceph created
```

Verify all ceph pods are running. The rook-ceph-osd-prepare pods will be in completed status.

```bash
$ kubectl get po -n rook-ceph
NAME                                                      READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-dccsx                                    3/3     Running     0          25m
csi-cephfsplugin-kmxcn                                    3/3     Running     0          25m
csi-cephfsplugin-provisioner-84fcf498dd-nnd89             4/4     Running     0          25m
csi-cephfsplugin-provisioner-84fcf498dd-xklgp             4/4     Running     0          25m
csi-cephfsplugin-r9kwr                                    3/3     Running     0          25m
csi-rbdplugin-2dnlw                                       3/3     Running     0          25m
csi-rbdplugin-5bfnn                                       3/3     Running     0          25m
csi-rbdplugin-d2trb                                       3/3     Running     0          25m
csi-rbdplugin-provisioner-7997bbf8b5-grzjg                5/5     Running     0          25m
csi-rbdplugin-provisioner-7997bbf8b5-v76wc                5/5     Running     0          25m
rook-ceph-crashcollector-10.128.229.21-6ff755f57d-m9blm   1/1     Running     0          23m
rook-ceph-crashcollector-10.128.229.24-7b588d78dc-m97c9   1/1     Running     0          23m
rook-ceph-crashcollector-10.128.229.6-b6796d44f-fvmq4     1/1     Running     0          19m
rook-ceph-mgr-a-f4f7b5485-w2sm2                           1/1     Running     0          19m
rook-ceph-mon-a-5f6955f485-qjz5r                          1/1     Running     0          23m
rook-ceph-mon-b-7b8776db75-sv9hr                          1/1     Running     0          23m
rook-ceph-mon-d-d447845d4-259cm                           1/1     Running     0          18m
rook-ceph-operator-848b8bc676-bdhc6                       1/1     Running     0          94m
rook-ceph-osd-prepare-10.128.229.21-854tf                 0/1     Completed   0          19m
rook-ceph-osd-prepare-10.128.229.24-pljvj                 0/1     Completed   0          19m
rook-ceph-osd-prepare-10.128.229.6-l646x                  0/1     Completed   0          19m
rook-discover-7w89l                                       1/1     Running     0          94m
rook-discover-cm5vm                                       1/1     Running     0          94m
rook-discover-lddn2                                       1/1     Running     0          94m
```


Create the storage class
```bash
$ kubectl apply -f csi/rook/internal-ceph/1.4.6/4-storageclass.yaml
cephblockpool.ceph.rook.io/replicapool created
storageclass.storage.k8s.io/rook-ceph-block created

$ k get sc
NAME              PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   5s
```

Install the toolbox to run commands to validate the cluster
```bash
$ kubectl apply -f csi/rook/internal-ceph/1.4.6/5-toolbox.yaml
deployment.apps/rook-ceph-tools created
```

One can validate ceph cluster status from the toolbox pod as shown below

```bash
$ kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" \
  -o jsonpath='{.items[0].metadata.name}') bash

[root@worker03 /]# ceph status
  cluster:
    id:     bd07342c-5dc3-4565-ab3e-cd70de7dfd83
    health: HEALTH_WARN
            too few PGs per OSD (8 < min 30)

  services:
    mon: 3 daemons, quorum a,b,d (age 68m)
    mgr: a(active, since 46s)
    osd: 3 osds: 3 up (since 63m), 3 in (since 63m)

  data:
    pools:   1 pools, 8 pgs
    objects: 6 objects, 35 B
    usage:   3.0 GiB used, 54 GiB / 57 GiB avail
    pgs:     8 active+clean

[root@worker03 /]# ceph osd tree
ID CLASS WEIGHT  TYPE NAME              STATUS REWEIGHT PRI-AFF
-1       0.05576 root default
-3       0.01859     host 10-12-2-21
 0   hdd 0.01859         osd.0              up  1.00000 1.00000
-7       0.01859     host 10-12-2-24
 1   hdd 0.01859         osd.1              up  1.00000 1.00000
-5       0.01859     host 10-12-2-6
 2   hdd 0.01859         osd.2              up  1.00000 1.00000

 [root@worker03 /]# ceph osd status
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
| id |      host  |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | 10.12.2.21 | 1027M | 17.9G |    0   |     0   |    0   |     0   | exists,up |
| 1  | 10.12.2.24 | 1027M | 17.9G |    0   |     0   |    0   |     0   | exists,up |
| 2  |  10.12.2.6 | 1027M | 17.9G |    0   |     0   |    0   |     0   | exists,up |
+----+------------+-------+-------+--------+---------+--------+---------+-----------+

```

Create a test pvc from the storageclass
```bash
$ kubectl apply -f csi/rook/internal-ceph/1.4.6/6-pvc.yaml
persistentvolumeclaim/rbd-pvc configured
```

Validate the PVC is bound to a pv from rook-ceph-block storage class.
```bash
$ kubectl get pv,pvc
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS      REASON   AGE
persistentvolume/pvc-f5f8dd87-5361-4114-ab40-81f666646d17   1Gi        RWO            Delete           Bound    default/rbd-pvc   rook-ceph-block            65m

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
persistentvolumeclaim/rbd-pvc   Bound    pvc-f5f8dd87-5361-4114-ab40-81f666646d17   1Gi        RWO            rook-ceph-block   122m
```

The Storage Class will also be visible in the PMK UI

![sc_ui](https://github.com/KoolKubernetes/csi/blob/master/rook/images/sc_ui.png)


# Enabling CSI Snapshot functionality

There are certain use-cases where you need volume Snapshot functionality and you need to have `volumesnapshotclasses`,`volumesnapshotcontents` and `volumesnapshots`  objects present on the cluster.


This can be implemented by running the following commands.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
```

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
```


```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
```


```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
```

```bash
kubectl apply -f https://github.com/kubernetes-csi/external-snapshotter/blob/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```


Finally, we'll deploy the Snapshot class that's needed for creating Volume Snapshots -

```bash
kubectl apply -f csi/rook/internal-ceph/1.4.6/8-snapshot-class.yaml
```

Now let's test the volumeSnapshot creation and restore by creating a test volumeSnapshot. If you have not already created a test snapshot as mentioned earlier, run the following command to create it -


```bash
kubectl apply -f csi/rook/internal-ceph/1.4.6/6-pvc.yaml
```

Next, create a snapshot by running the following command -

```bash
kubectl apply -f csi/rook/internal-ceph/1.4.6/9-volume-snapshot.yaml
```


Ensure that you're able to observe the volume snapshot in the following command -
```bash
kubectl get volumesnapshots
```

Now, lets restore the snapshot -

```bash
kubectl apply -f 10-volume-snapshot-restore.yaml
```

You should now be able to observe both the pv and the associated snapshots.
