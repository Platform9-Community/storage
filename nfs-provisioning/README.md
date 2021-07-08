## Dynamic NFS Provisioner Kubernetes

- Pre-Requisites for Dynamic NFS Provisioning in Kubernetes
- Linux Work Station
- K8 Cluster
- Kubernetes-cli or kubectl program
- Kubernetes versions 1.19.6 - 1.20.5 (other versions have **not** been verified)
- Routable IP network with DHCP configured

### Step 1) Installing the NFS Server
In this particular example we’ll allocate a local filesystem from which PersistenceVolume Claims can be made. We’ll first create “/srv/nfs/kubedata“

- `[root@cluster-50-master ~]#  mkdir /srv/nfs/kubedata -p`

Change the ownership to “nfsnobody”

- `[root@cluster-50-master ~]# chown nfsnobody: /srv/nfs/kubedata/`

Next install the nfs-utils. This exanple is for centos 7

- `[root@cluster-50-master ~]# yum install -y nfs-utils`

Next, enable and start the userspace nfs server using systemctl.

- `[root@cluster-50-master ~]# systemctl enable nfs-server`

Created symlink from /etc/systemd/system/multi-user.target.wants/nfs-server.service to /usr/lib/systemd/system/nfs-server.service.

- `[root@cluster-50-master ~]# systemctl start nfs-server`

- `[root@cluster-50-master ~]# systemctl status nfs-server`

● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
   Active: active (exited) since Wed 2020-08-26 16:25:06 UTC; 5s ago
   
Next, we need to edit the exports file to add the file system we created to be exported to remote hosts.
 - `[root@cluster-50-master ~]# vi /etc/exports`
 
/srv/nfs/kubedata    *(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)

Next, run the exportfs command to make the local directory we configured available to remote hosts.

- `[root@cluster-50-master ~]# exportfs -rav`

exporting *:/srv/nfs/kubedata

If you want to see more details about our export file system, you can run “exportfs -v”.

- `[root@cluster-50-master ~]# exportfs -v`

/srv/nfs/kubedata
        <world>(sync,wdelay,hide,no_subtree_check,sec=sys,rw,insecure,no_root_squash,no_all_squash)

Next, let’s test the nfs configurations. Log onto one of the worker nodes and mount the nfs filesystem and
verify.

- `[root@cluster-50-node-02 ~]# mount -t nfs 192.168.50.20:/srv/nfs/kubedata /mnt`

[root@cluster-50-node-02 ~]#  mount | grep kubedata
192.168.50.20:/srv/nfs/kubedata on /mnt type nfs4 (rw,relatime,vers=4.1,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.50.16,local_lock=none,addr=192.168.50.20)

After verifying that NFS is confgured correctly and working we can un-mount the filesystem.
- `[root@cluster-50-node-02 ~]# sudo umount /mnt)`



### Step 2) Deploying Service Account and Role Bindings

Next, we’ll configure a service account and role bindings. We’ll use role-based access control to do the configuration. First step is to download the nfs-provisioning repo and change into the nfs-provisioning directory.

```
git clone https://github.com/Platform9-Community/storage.git

cd nfs-provisioning
```

In this directory we have 4 files. (class.yaml default-sc.yaml deployment.yaml rbac.yaml) We will use the rbac.yaml file to create the service account for nfs and cluster role and bindings.

- `[root@cluster-50-master ~]# kubectl create -f rbac.yaml`

We can verify that the service account, clusterrole and binding was created.

```
[root@cluster-50-master ~]# kubectl get clusterrole,clusterrolebinding,role,rolebinding | grep nfs
clusterrole.rbac.authorization.k8s.io/nfs-client-provisioner-runner 20m
clusterrolebinding.rbac.authorization.k8s.io/run-nfs-client-provisioner 20m
role.rbac.authorization.k8s.io/leader-locking-nfs-client-provisioner 20m
rolebinding.rbac.authorization.k8s.io/leader-locking-nfs-client-provisioner 20m
```

### Step 3) Deploying Storage Class
Next let’s run the “class.yaml” to set up the storageclass. A storageclass provides a way for administrators to describe the “classes” of storage they offer.

Let’s edit the “class.yaml” file and set both the storageclass name and the provisioner name.

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
name: managed-nfs-storage
provisioner: example.com/nfs
parameters:
archiveOnDelete: “false”
```

Once we’ve updated the class.yaml file we can execute the file using kubectl create

```
[root@cluster-50-master ~]# kubectl create -f class.yaml
storageclass.storage.k8s.io/managed-nfs-storage created
Next, check that the storage class was created.
[root@cluster-50-master ~]# kubectl get storageclass
NAME                  PROVISIONER       AGE
managed-nfs-storage   example.com/nfs   48s
```

### Step 4) Deploying NFS Provisioner
Now let’s deploy the nfs provisioner. But first we’ll need to edit the deployment.yaml file. In this file we’ll need to specify the IP Address of our NFS Server (kmaster) 192.168.50.20.

```
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-client-provisioner
spec:
  selector:
    matchLabels:
      app: nfs-client-provisioner
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: example.com/nfs
            - name: NFS_SERVER
              value: 192.168.50.20
            - name: NFS_PATH
              value: /srv/nfs/kubedata
      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.50.20
            path: /srv/nfs/kubedata
```

Once we’ve made the changes, save the file and apply the changes by running “kubectl create”.

```
[root@cluster-50-master ~]# kubectl create -f deployment.yaml
deployment.apps/nfs-client-provisioner created
```

After applying the changes, we should see a pod was created for nfs-client-provisioner.

```
[root@cluster-50-master kubedata]#   kubectl get all
NAME                                          READY   STATUS    RESTARTS   AGE
pod/nfs-client-provisioner-67dfcbfd99-wc9zb   1/1     Running   0          58m

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.155.0.1   <none>        443/TCP   43h

NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nfs-client-provisioner   1/1     1            1           58m

NAME                                                DESIRED   CURRENT   READY   AGE
replicaset.apps/nfs-client-provisioner-67dfcbfd99   1         1         1       58m
[root@cluster-50-master kubedata]# kubectl describe pod nfs-client-provisioner-67dfcbfd99-wc9zb
Name:         nfs-client-provisioner-67dfcbfd99-wc9zb
Namespace:    default
Priority:     0
Node:         192.168.50.14/192.168.50.14
Start Time:   Wed, 26 Aug 2020 16:02:52 +0000
Labels:       app=nfs-client-provisioner
              pod-template-hash=67dfcbfd99
Annotations:  <none>
Status:       Running
IP:           10.135.1.15
IPs:
  IP:           10.135.1.15
Controlled By:  ReplicaSet/nfs-client-provisioner-67dfcbfd99
Containers:
  nfs-client-provisioner:
    Container ID:   docker://6a94fd212535c703ff7f8bdf5063745c9c149c91663ccf5a6888adc286bb3507
    Image:          k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Wed, 26 Aug 2020 16:03:04 +0000
    Ready:          True
    Restart Count:  0
    Environment:
      PROVISIONER_NAME:  example.com/nfs
      NFS_SERVER:        192.168.50.20
      NFS_PATH:          /srv/nfs/kubedata
    Mounts:
      /persistentvolumes from nfs-client-root (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from nfs-client-provisioner-token-spzg5 (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  nfs-client-root:
    Type:      NFS (an NFS mount that lasts the lifetime of a pod)
    Server:    192.168.50.20
    Path:      /srv/nfs/kubedata
    ReadOnly:  false
  nfs-client-provisioner-token-spzg5:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  nfs-client-provisioner-token-spzg5
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age        From                    Message
  ----    ------     ----       ----                    -------
  Normal  Scheduled  <unknown>  default-scheduler       Successfully assigned default/nfs-client-provisioner-67dfcbfd99-wc9zb to 192.168.50.14
  Normal  Pulling    59m        kubelet, 192.168.50.14  Pulling image "k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2"
  Normal  Pulled     59m        kubelet, 192.168.50.14  Successfully pulled image "k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2"
  Normal  Created    59m        kubelet, 192.168.50.14  Created container nfs-client-provisioner
  Normal  Started    59m        kubelet, 192.168.50.14  Started container nfs-client-provisioner
```

### Step 5) Creating Persistent Volume and Persistent Volume Claims

Persistent Volume Claims are objects that request storage resources from your cluster. They’re similar to a voucher that your deployment can redeem for storage access.

Persistent Volume is resource that can be used by a pod to store data that will persist beyond the lifetime of the pod. It is a storage volume that in this case is a nfs volume.

If we check our cluster we’ll see that there are currently no Persistent Volumes or Persistent Volume Claims.

```
[root@cluster-50-master]# kubectl get pv,pvc
No resources found in default namespace.
```

Also, we can look in the directory we allocated for Persistent Volumes and see there nothing there.

```
[root@cluster-50-master]# ls /srv/nfs/kubedata/
```
   
Let’s create a PVC. Inside the nfs-provisioning repo there is a file “4-pvc-nfs.yaml”. In this example, we will allocate 500 MegaBytes.

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
spec:
  storageClassName: managed-nfs-storage
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
```

We can create the PVC by running “kubectl create” against the 4-pvc-nfs.yaml” file.
```
[root@cluster-50-master]# kubectl create -f 4-pvc-nfs.yaml
persistentvolumeclaim/pvc1 created
```
We can now view the PVC and PV that was allocated. As we can see below a PCV was created “persistentvolumeclaim/pvc1” and its bound to a PV “pvc-eca295aa-bc2c-420c-b60e-9a6894fc9daf”. The PV was created automatically by the nfs-provisoner.

```
[root@cluster-50-master ~]# kubectl get pvc,pv
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          AGE
persistentvolumeclaim/pvc1   Bound    pvc-eca295aa-bc2c-420c-b60e-9a6894fc9daf   500Mi      RWX            managed-nfs-storage   2m30s
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM          STORAGECLASS          REASON   AGE
persistentvolume/pvc-eca295aa-bc2c-420c-b60e-9a6894fc9daf   500Mi      RWX            Delete           Bound    default/pvc1   managed-nfs-storage            2m30s
[root@cluster-50-master ~]#
```

### Step 6) Creating a Pod to use Persistent Volume Claims

Now that we have our nfs-provisoner working and we have both a PVC and OV that it is bound to. Let’s create a pod to use our PVC. If we take a quick look at the existing pods we’ll see that only the “nfs-client-provisioner” pod is running.

```
[root@cluster-50-master]# kubectl get pods
NAME                                      READY   STATUS    RESTARTS   AGE
nfs-client-provisioner-5b4f5775c7-9j2dw   1/1     Running   0          4h36m
```
Next, we’ll create a pod using the “4-busybox-pv-nfs.yaml” file. But first lets take a look at the files contents.
apiVersion: v1

```
kind: Pod
metadata:
  name: busybox
spec:
  volumes:
  - name: host-volume
    persistentVolumeClaim:
      claimName: pvc1
  containers:
  - image: busybox
    name: busybox
    command: ["/bin/sh"]
    args: ["-c", "sleep 600"]
    volumeMounts:
    - name: host-volume
      mountPath: /mydata
```

We’ll execute test-pod-pvc1.yaml using “kubectl create”.

```
[root@cluster-50-master ~]# kubectl create -f 4-busybox-pv-nfs.yaml
pod/busybox created
```

We can now see that the pod is up and running.

```
[root@cluster-50-master]# kubectl get pods
NAME                                      READY   STATUS    RESTARTS   AGE
busybox                                   1/1     Running   0          8s
nfs-client-provisioner-67dfcbfd99-wc9zb   1/1     Running   0          111m
```

We can describe the pod to see more details.

```
[root@cluster-50-master ~]# kubectl describe pod busybox
Name:         busybox
Namespace:    default
Priority:     0
Node:         kworker1.example.com/172.42.42.101
Start Time:   Mon, 04 Nov 2019 03:44:30 +0000
[root@cluster-50-master]# kubectl describe pod busybox
Name:         busybox
Namespace:    default
Priority:     0
Node:         192.168.50.14/192.168.50.14
Start Time:   Wed, 26 Aug 2020 17:54:40 +0000
Labels:       <none>
Annotations:  <none>
Status:       Running
IP:           10.135.1.17
IPs:
  IP:  10.135.1.17
Containers:
  busybox:
    Container ID:  docker://09ac40f8ac45ce8d65d3bffb0b0f382836f4d5dc46f3ac11a6d51607c4bdfd8f
    Image:         busybox
    Image ID:      docker-pullable://busybox@sha256:4f47c01fa91355af2865ac10fef5bf6ec9c7f42ad2321377c21e844427972977
    Port:          <none>
    Host Port:     <none>
    Command:
      /bin/sh
    Args:
      -c
      sleep 600
    State:          Running
      Started:      Wed, 26 Aug 2020 17:54:45 +0000
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /mydata from host-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-4rkd9 (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  host-volume:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  pvc1
    ReadOnly:   false
  default-token-4rkd9:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-4rkd9
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age        From                    Message
  ----    ------     ----       ----                    -------
  Normal  Scheduled  <unknown>  default-scheduler       Successfully assigned default/busybox to 192.168.50.14
  Normal  Pulling    34s        kubelet, 192.168.50.14  Pulling image "busybox"
  Normal  Pulled     33s        kubelet, 192.168.50.14  Successfully pulled image "busybox"
  Normal  Created    31s        kubelet, 192.168.50.14  Created container busybox
  Normal  Started    30s        kubelet, 192.168.50.14  Started container busybox
```

We can log into the container to view the mount point and create a file for testing

```
[root@cluster-50-master]# kubectl exec -it busybox -- ./bin/sh
/ # ls /mydata/
/ # > /mydata/pf9file
/ # ls /mydata/
pf9file
```

Now that we’ve create a file called myfile, we can log into the mastrer node and verify the file by looking in the PV directory that was allocated for this pod.

```
[root@cluster-50-master]# ls /srv/nfs/kubedata/default-pvc1-pvc-774d202f-2fa1-4820-8ccb-8b5bf58fa926/
pf9file
```

### Step 7) Deleting Pods with Persistent Volume Claims

To delete the pod just use “kubectl delete pod [pod name]”

```
[root@cluster-50-master]# kubectl delete pod busybox
pod "busybox" deleted
```

Deleting the pod will delete the pod but not the PV and PVC. This will have to be done separately.

```
[root@cluster-50-master]# kubectl get pvc,pv
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          AGE
persistentvolumeclaim/pvc1   Bound    pvc-774d202f-2fa1-4820-8ccb-8b5bf58fa926   500Mi      RWX            managed-nfs-storage   43m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM          STORAGECLASS          REASON   AGE
persistentvolume/pvc-774d202f-2fa1-4820-8ccb-8b5bf58fa926   500Mi      RWX            Delete           Bound    default/pvc1   managed-nfs-storage            43m
```

To delete the PV and PVC use “kubectl delete”

```
[root@cluster-50-master]# kubectl delete pvc --all
persistentvolumeclaim "pvc1" deleted

[root@cluster-50-master kubedata]# kubectl get pvc,pv
No resources found in default namespace.
```
