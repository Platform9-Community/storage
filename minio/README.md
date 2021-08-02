## DRAFT

# Running a secure cloud-native object storage with platform9 kubernets and MinIO object storage
Following this page one can deploy a secure cloud native object storage using the most recent MinIO operator on platform9 managed kubernetes cluster. 

# Prerequisites:

Kubernetes:
A descently sized platform9 managed kubernetes cluster
Masters: minimum 1, 3 for HA
Cluster nodes (Workers): 4
Node Sizing: 4VCPUs x 16GiBs
Disks: 1 x 100GiB for OS and 1 x 30GiB for rook-ceph CSI.
Persistent Storage: Any kubenetes CSI pre-configured on the cluster will do the job of allocating persistent storgae to the minIO tenants. Please refer the platform9 community [page](https://github.com/KoolKubernetes/csi/tree/master/rook/) for setting up a persistent storage whith rook on platform9 managed kubernetes 1.19 and 1.20.
Kubernetes Version required: 1.20
Platform9 version: 5.2+
For bare minimum configuration nodes with 2VCPUs and 4GB memory will be sufficient. One should be able to provision one or two min-IO tenants on such cluster.
On your on-premise setups configure metallb to access the min-IO operator and tenant consoles over the loadbalancer type service.

TLS certificates:
[cert-manager](https://cert-manager.io/docs/release-notes/release-notes-1.4/)
Recommended version: v1.4.1

min-IO:



# Note:
The deployment will work with any platform9 plans. You may login with a platform9 free tier account to spin up the cluster on your private or public cloud infrastructure.

# deploy cert-manager
deploy cert-managr with helm chart or through the manifest provided on the cert-manager website. 

Installing with helm-chart:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.4.0 \
  --set installCRDs=true
```
Install with kubectl:
```bash
kubectl apply -f  cert-manager/cert-manager-v1.4.1.yaml
```
In order to install the latest cert-manager with kubectl:
```bash
kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.yaml
```

Validate self-signed certificate gets issued by cert-manager:
```bash
kubectl apply -f cert-manager/test-resources.yaml
```
Validate certificate has been issued. At this point the cert-manager is ready for issuing the certificates. 
```bash
kubectl describe certificate selfsigned-cert
```
With cert-manager one can create certificate issuer under namespace as well as at cluster level. Here we are going to keep the inssuer's scope specific to the namespace.

# deploy minio-operator
Min-IO operator requires a kubernetes opaque type secret called as 'operator-tls'. This secret can be created from the private key file and certificate issues from cert-manager. 
With cert-managet first create a Issuer and issue a certificate. 
```bash
kubectl apply -f operator/operator-tls-tls.yaml
```

This manifest creates minio-operator namespace, a certificate Issuer called as minio-operator and finally issues a certificate 'operator-tls-tls' from the issuer in the minio-operator namespace. Beyond this cert-manager also creates a secret with the same name that has the certificate, CA certificate and the private key file. extract the tls.crt and tls.key from the secret 'operator-tls-tls' and create a secret called as operator-tls by running following commands:
```bash

```





```bash

```
```bash

```

Install [rook](https://github.com/Platform9-Community/csi/tree/master/rook) CSI driver. Follow steps till rook-ceph cluster creation. Apply the manifest provided in this [repository](repo/rook/4-storageclass.waitforfirstconsumer.yaml) to deploy the storage class. If this fails to allocate volumes then an alternate storage class yaml is also provided in the same [repository](repo/rook/4-storageclass-immediate.yaml).

Create the storage class
```bash
kubectl apply -f rook/4-storageclass.waitforfirstconsumer.yaml
```
```bash
kubectl get sc
NAME                        PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   4d3h
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
