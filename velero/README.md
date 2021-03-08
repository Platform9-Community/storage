# Backup and restore kubernetes namespaces using velero on Platform9 Managed Kubernetes (PMK)

Here we are going to backup Jenkins using velero from a PMK 4.3 cluster and restore it to second PMK cluster using velero's restic file level backup feature. This typically depicts a cloud to cloud migration scenario for an kubernetes application and its persistent volume data.

# Components required (Tested with):
PMK clusters: 2 x PMK 4.3 four node clusters (Each with Single Master and Three worker nodes)

CNI: flannel

Persistent Storage: Rook CSI 

S3 storage: MINIO

App: Jenkins

Note: Restic file backup does not support hostPath type of volumes.

# Architecture:
Velero needs its server component running in kubernets cluster where a backup is initiated. A velero client very similar to kubectl is used to connect with the velero servers on multiple kubernetes clusters via the kubefig present on the user system from where client is running. Velero server needs S3 bucket to store the kubernetes backup. The S3 bucket can be created localy on the source kubernetes cluster using a opensource object storage called as MINIO. Velero server installed on the destination kubernetes clusters has to have access to the MINIO bucket's public endpoint in order to query and restore the backup. A reference to this architecture can e found on google by earching for velero and clicking on 'Images' below the search bar.


# Kubernetes Build
Using the platform9 free tier account or your platform9 management plane carve two PMK 4.3+ (kubernetes 1.16+) clusters. We have tested this with flannel CNI and Rook CSI. Please refer [Rook](https://github.com/KoolKubernetes/csi/tree/master/rook/) to configure the Rook CSI on both PMK clusters.

# Deploy velero
Once your both kubernetes clusters are ready with Rook CSI create storage class named 'rook-ceph-block' in both the clusters. Refer the Rook koolkubernetes readme under csi repository for setting this up.

Point the kubectl context to your first kubernetes cluster as show below
```bash
$ k config get-contexts
CURRENT   NAME   CLUSTER               AUTHINFO                     NAMESPACE
*         cl4    cl4.platform9.horse   surendra@platform9.net.cl4   default
          cl5    cl5.platform9.horse   surendra@platform9.net.cl5   default
          cl6    cl6.platform9.horse   surendra@platform9.net.cl6   default
```
Download the latest stable release of velero, extract it and move into your system path.
```bash
$ wget https://github.com/vmware-tanzu/velero/releases/download/v1.4.2/velero-v1.4.2-linux-amd64.tar.
$ tar xvf velero-v1.4.2-linux-amd64.tar.gz -C .
$ sudo chown root:root velero
$ sudo mv velero /usr/local/bin
```
Install minio inside the first kubernetes cluster. 
```bash
$ git clone https://github.com/KoolKubernetes/objectstorage.git
$ kubectl apply -f objectstorage/minio/minio-velero-nodeport.yaml
namespace/velero created
deployment.apps/minio created
service/minio created
job.batch/minio-setup created

$ kubectl get ns
NAME                   STATUS   AGE
default                Active   20h
kube-node-lease        Active   20h
kube-public            Active   20h
kube-system            Active   20h
kubernetes-dashboard   Active   20h
pf9-monitoring         Active   20h
pf9-olm                Active   20h
pf9-operators          Active   20h
rook-ceph              Active   3h39m
velero                 Active   39s

$ kubectl get pods -n velero
NAME                    READY   STATUS      RESTARTS   AGE
minio-d787f4bf7-wqpr7   1/1     Running     0          56s
minio-setup-tvpb2       0/1     Completed   2          57s
```
Minio can be accessed now using the cl4 API endpoint and the nodeport showin in the minio service.

Install velero on the first cluster
```bash
velero install \
     --provider aws \
     --plugins velero/velero-plugin-for-aws:v1.1.0,velero/velero-plugin-for-csi:v0.1.1 \
     --bucket velero \
     --secret-file ./credentials-velero \
     --use-volume-snapshots=false \
     --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000,publicUrl=http://10.128.240.197:30673 \
     --use-restic \
     --kubeconfig ~/.kube/config \
     --image "velero/velero:v1.4.2" \
     --prefix cl4
CustomResourceDefinition/backups.velero.io: attempting to create resource
CustomResourceDefinition/backups.velero.io: created
CustomResourceDefinition/backupstoragelocations.velero.io: attempting to create resource
CustomResourceDefinition/backupstoragelocations.velero.io: created
CustomResourceDefinition/deletebackuprequests.velero.io: attempting to create resource
CustomResourceDefinition/deletebackuprequests.velero.io: created
CustomResourceDefinition/downloadrequests.velero.io: attempting to create resource
CustomResourceDefinition/downloadrequests.velero.io: created
CustomResourceDefinition/podvolumebackups.velero.io: attempting to create resource
CustomResourceDefinition/podvolumebackups.velero.io: created
CustomResourceDefinition/podvolumerestores.velero.io: attempting to create resource
CustomResourceDefinition/podvolumerestores.velero.io: created
CustomResourceDefinition/resticrepositories.velero.io: attempting to create resource
CustomResourceDefinition/resticrepositories.velero.io: created
CustomResourceDefinition/restores.velero.io: attempting to create resource
CustomResourceDefinition/restores.velero.io: created
CustomResourceDefinition/schedules.velero.io: attempting to create resource
CustomResourceDefinition/schedules.velero.io: created
CustomResourceDefinition/serverstatusrequests.velero.io: attempting to create resource
CustomResourceDefinition/serverstatusrequests.velero.io: created
CustomResourceDefinition/volumesnapshotlocations.velero.io: attempting to create resource
CustomResourceDefinition/volumesnapshotlocations.velero.io: created
Waiting for resources to be ready in cluster...
Namespace/velero: attempting to create resource
Namespace/velero: already exists, proceeding
Namespace/velero: created
ClusterRoleBinding/velero: attempting to create resource
ClusterRoleBinding/velero: created
ServiceAccount/velero: attempting to create resource
ServiceAccount/velero: created
Secret/cloud-credentials: attempting to create resource
Secret/cloud-credentials: created
BackupStorageLocation/default: attempting to create resource
BackupStorageLocation/default: created
Deployment/velero: attempting to create resource
Deployment/velero: created
DaemonSet/restic: attempting to create resource
DaemonSet/restic: created
Velero is installed! ⛵ Use 'kubectl logs deployment/velero -n velero' to view the status.     
```

Here:
s3Url is the IP and port of S3 endpoint which is internally accessible from within the kubernetes cluster.
For on-premises clusters the provider type is aws.
Since there are no volume snapshot providers in this cluster the volume snapshot flag is disabled. This can be enabled in plublic cloud or if the volume snapshot providers is present.
The restic feature is used to take file level backups.
publicUrl - This option represents the the IP and port of the MINIO S3 endpoint accessible from outside the first kubernetes cluster for the velero server just installed. 10.128.240.197 is the IP of the kubernetes API endpoint. MINIO nodeport service that was earlier created has obtained port 30673 on the nodes.

Validate velero service and backup location is now present in the cluster. If you login to MINIO from its UI you can now see the cl4 directory under the velero bucket.

```bash
$ velero backup-location get
NAME      PROVIDER   BUCKET/PREFIX   ACCESS MODE
default   aws        velero/cl4      ReadWrite


$ k get svc -n velero
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
minio   NodePort   10.21.178.139   <none>        9000:30673/TCP   5d3h
```

Deploy Jenkins on first cluster. Note this deployment needs a stroage class named 'rook-ceph-block' already deployed from rook.
```bash
$ git clone https://github.com/KoolKubernetes/backup.git
$ kubectl apply backup/velero/jenkins.yaml
```

Validate Jenkins is up and running.

```bash
$ k get all
NAME                           READY   STATUS    RESTARTS   AGE
pod/jenkins-58b8d7456d-vtz9r   1/1     Running   0          16h


NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                          AGE
service/jenkins      NodePort    10.21.188.41   <none>        8080:31330/TCP,50000:31125/TCP   16h
service/kubernetes   ClusterIP   10.21.0.1      <none>        443/TCP                          44h


NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/jenkins   1/1     1            1           16h

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/jenkins-58b8d7456d   1         1         1       16h
```


Annotate Jenkins pod with the jenkins home name to be backed up during velero backup of jenkins namespace.

```bash
$ k annotate pods jenkins-58b8d7456d-vtz9r backup.velero.io/backup-volumes=jenkins-home --overwrite
pod/jenkins-58b8d7456d-vtz9r annotated
```

Operationalize jenkins. Access jenkins from UI and create test pipelines, install and update some plugins.
Now Backup jenkins namespace and its volume with velero.

```bass
$ velero backup create jenkins-cl4 --include-namespaces default
Backup request "jenkins-cl4" submitted successfully.
Run `velero backup describe jenkins-cl4` or `velero backup logs jenkins-cl4` for more details.

$ velero backup describe jenkins-cl4
Name:         jenkins-cl4
Namespace:    velero
Labels:       velero.io/storage-location=default
Annotations:  velero.io/source-cluster-k8s-gitversion=v1.16.10
              velero.io/source-cluster-k8s-major-version=1
              velero.io/source-cluster-k8s-minor-version=16

Phase:  InProgress

Errors:    0
Warnings:  0

Namespaces:
  Included:  default
  Excluded:  <none>

Resources:
  Included:        *
  Excluded:        <none>
  Cluster-scoped:  auto

Label selector:  <none>

Storage Location:  default

Velero-Native Snapshot PVs:  auto

TTL:  720h0m0s

Hooks:  <none>

Backup Format Version:  1

Started:    2020-08-06 09:15:23 +0000 UTC
Completed:  <n/a>

Expiration:  2020-09-05 09:15:23 +0000 UTC

Estimated total items to be backed up:  16
Items backed up so far:                 0

Velero-Native Snapshots: <none included>

Restic Backups (specify --details for more information):
  In Progress:  1
ubuntu@admin-surendra:~$
```

Verify the backup is completed. 

Now switch the context to second cluster
```bash
$ k config get-contexts
CURRENT   NAME   CLUSTER               AUTHINFO                     NAMESPACE
          cl4    cl4.platform9.horse   surendra@platform9.net.cl4   default
          cl5    cl5.platform9.horse   surendra@platform9.net.cl5   default
*         cl6    cl6.platform9.horse   surendra@platform9.net.cl6   default
```

Install velero on it
```bash
$ velero install \
>      --provider aws \
>      --plugins velero/velero-plugin-for-aws:v1.1.0 \
>      --bucket velero \
>      --secret-file ./credentials-velero \
>      --use-volume-snapshots=false \
>      --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://10.128.240.197:30673,publicUrl=http://10.128.240.197:30673 \
>      --use-restic \
>      --kubeconfig ~/.kube/config \
>      --image "velero/velero:v1.4.2" \
>      --prefix cl4
CustomResourceDefinition/backups.velero.io: attempting to create resource
CustomResourceDefinition/backups.velero.io: already exists, proceeding
CustomResourceDefinition/backups.velero.io: created
CustomResourceDefinition/backupstoragelocations.velero.io: attempting to create resource
CustomResourceDefinition/backupstoragelocations.velero.io: already exists, proceeding
CustomResourceDefinition/backupstoragelocations.velero.io: created
CustomResourceDefinition/deletebackuprequests.velero.io: attempting to create resource
CustomResourceDefinition/deletebackuprequests.velero.io: already exists, proceeding
CustomResourceDefinition/deletebackuprequests.velero.io: created
CustomResourceDefinition/downloadrequests.velero.io: attempting to create resource
CustomResourceDefinition/downloadrequests.velero.io: already exists, proceeding
CustomResourceDefinition/downloadrequests.velero.io: created
CustomResourceDefinition/podvolumebackups.velero.io: attempting to create resource
CustomResourceDefinition/podvolumebackups.velero.io: already exists, proceeding
CustomResourceDefinition/podvolumebackups.velero.io: created
CustomResourceDefinition/podvolumerestores.velero.io: attempting to create resource
CustomResourceDefinition/podvolumerestores.velero.io: already exists, proceeding
CustomResourceDefinition/podvolumerestores.velero.io: created
CustomResourceDefinition/resticrepositories.velero.io: attempting to create resource
CustomResourceDefinition/resticrepositories.velero.io: already exists, proceeding
CustomResourceDefinition/resticrepositories.velero.io: created
CustomResourceDefinition/restores.velero.io: attempting to create resource
CustomResourceDefinition/restores.velero.io: already exists, proceeding
CustomResourceDefinition/restores.velero.io: created
CustomResourceDefinition/schedules.velero.io: attempting to create resource
CustomResourceDefinition/schedules.velero.io: already exists, proceeding
CustomResourceDefinition/schedules.velero.io: created
CustomResourceDefinition/serverstatusrequests.velero.io: attempting to create resource
CustomResourceDefinition/serverstatusrequests.velero.io: already exists, proceeding
CustomResourceDefinition/serverstatusrequests.velero.io: created
CustomResourceDefinition/volumesnapshotlocations.velero.io: attempting to create resource
CustomResourceDefinition/volumesnapshotlocations.velero.io: already exists, proceeding
CustomResourceDefinition/volumesnapshotlocations.velero.io: created
Waiting for resources to be ready in cluster...
Namespace/velero: attempting to create resource
Namespace/velero: already exists, proceeding
Namespace/velero: created
ClusterRoleBinding/velero: attempting to create resource
ClusterRoleBinding/velero: already exists, proceeding
ClusterRoleBinding/velero: created
ServiceAccount/velero: attempting to create resource
ServiceAccount/velero: already exists, proceeding
ServiceAccount/velero: created
Secret/cloud-credentials: attempting to create resource
Secret/cloud-credentials: already exists, proceeding
Secret/cloud-credentials: created
BackupStorageLocation/default: attempting to create resource
BackupStorageLocation/default: created
Deployment/velero: attempting to create resource
Deployment/velero: created
DaemonSet/restic: attempting to create resource
DaemonSet/restic: created
Velero is installed! ⛵ Use 'kubectl logs deployment/velero -n velero' to view the status.

$ k get pods -n velero
NAME                      READY   STATUS    RESTARTS   AGE
restic-jpj2v              1/1     Running   0          63s
restic-rphcp              1/1     Running   0          63s
restic-v95dz              1/1     Running   0          63s
velero-7c6d9bb58d-zt2ft   1/1     Running   0          63s
```

Validate velero on second cluster can communicate with the same MINIO s3 bucket and list the backups
```bash
$ velero backup get
NAME          STATUS            ERRORS   WARNINGS   CREATED                         EXPIRES   STORAGE LOCATION   SELECTOR
jenkins-cl4   Completed         0        0          2020-08-06 09:15:23 +0000 UTC   25d       default            <none>

$ velero backup describe jenkins-cl4 --details
Name:         jenkins-cl4
Namespace:    velero
Labels:       velero.io/storage-location=default
Annotations:  velero.io/source-cluster-k8s-gitversion=v1.16.10
              velero.io/source-cluster-k8s-major-version=1
              velero.io/source-cluster-k8s-minor-version=16

Phase:  Completed

Errors:    0
Warnings:  0

Namespaces:
  Included:  default
  Excluded:  <none>

Resources:
  Included:        *
  Excluded:        <none>
  Cluster-scoped:  auto

Label selector:  <none>

Storage Location:  default

Velero-Native Snapshot PVs:  auto

TTL:  720h0m0s

Hooks:  <none>

Backup Format Version:  1

Started:    2020-08-06 09:15:23 +0000 UTC
Completed:  2020-08-06 09:15:59 +0000 UTC

Expiration:  2020-09-05 09:15:23 +0000 UTC

Total items to be backed up:  20
Items backed up:              20

Resource List:
  apiextensions.k8s.io/v1/CustomResourceDefinition:
    - clusterserviceversions.operators.coreos.com
  apps/v1/Deployment:
    - default/jenkins
  apps/v1/ReplicaSet:
    - default/jenkins-58b8d7456d
  operators.coreos.com/v1alpha1/ClusterServiceVersion:
    - default/prometheusoperator.0.32.0
  rbac.authorization.k8s.io/v1/ClusterRole:
    - jenkinsclusterrole
  rbac.authorization.k8s.io/v1/ClusterRoleBinding:
    - jenkins-crb
  rbac.authorization.k8s.io/v1/Role:
    - default/jenkins
  rbac.authorization.k8s.io/v1/RoleBinding:
    - default/jenkins
  v1/Endpoints:
    - default/jenkins
    - default/kubernetes
  v1/Namespace:
    - default
  v1/PersistentVolume:
    - pvc-67ee285a-7d5f-4223-ba38-7696fd324892
  v1/PersistentVolumeClaim:
    - default/jenkinsci-pvc
  v1/Pod:
    - default/jenkins-58b8d7456d-vtz9r
  v1/Secret:
    - default/default-token-65gsh
    - default/jenkins-token-tbd6w
  v1/Service:
    - default/jenkins
    - default/kubernetes
  v1/ServiceAccount:
    - default/default
    - default/jenkins

Velero-Native Snapshots: <none included>

Restic Backups:
  Completed:
    default/jenkins-58b8d7456d-vtz9r: jenkins-home
```
Make sure you have the storage class named 'rook-ceph-block' present on the second cluster for volume provisioning before proceeding with restore.

Restore the backup on the second cluster.
```bash
$ velero restore create --from-backup jenkins-cl4
Restore request "jenkins-cl4-20200810135422" submitted successfully.
Run `velero restore describe jenkins-cl4-20200810135422` or `velero restore logs jenkins-cl4-20200810135422` for more details.

$ velero restore describe jenkins-cl4-20200810135422
Name:         jenkins-cl4-20200810135422
Namespace:    velero
Labels:       <none>
Annotations:  <none>

Phase:  InProgress

Backup:  jenkins-cl4

Namespaces:
  Included:  all namespaces found in the backup
  Excluded:  <none>

Resources:
  Included:        *
  Excluded:        nodes, events, events.events.k8s.io, backups.velero.io, restores.velero.io, resticrepositories.velero.io
  Cluster-scoped:  auto

Namespace mappings:  <none>

Label selector:  <none>

Restore PVs:  auto

Restic Restores (specify --details for more information):
  In Progress:  1
```

Validate Jenkins
```bash
$ k get pods
NAME                       READY   STATUS     RESTARTS   AGE
jenkins-58b8d7456d-vtz9r   0/1     Init:0/1   0          43s
```
```bash
$ k get pvc
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
jenkinsci-pvc   Bound    pvc-52f6cefe-4027-48f3-9f4f-53e38473a29f   10Gi       RWO            rook-ceph-block   49s  
```
Once Jenkins is running validate everything within Jenkins is as it was on the source kubernetes cluster.
