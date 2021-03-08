# Deploying OpenEBS on Platform9 Managed Kubernetes/Platform9 Managed Kubernetes Free Tier (PMK/PMKFT)

OpenEBS is  one of the leading open-source projects for  cloud-native storage on Kubernetes. OpenEBS adopts Container Attached Storage (CAS) approach, where each workload is provided with a dedicated storage controller. You can check out all the features and benefits in the [link](https://docs.openebs.io/docs/next/features.html) here.


### Prerequisites

Here are the prerequisites needed for installation of OpenEBS -

1. Working Helm 3 installation [link](https://helm.sh/docs/intro/install/).

2. Install `iscsi` related packages on all the nodes.

  i. For Ubuntu OS, here are the steps -
  ```bash
  sudo apt-get update
sudo apt-get install open-iscsi
sudo systemctl enable --now iscsid
```

 To ensure that iscsi services are functioning correctly,
   check the output of the following commands -

   ```bash
   sudo cat /etc/iscsi/initiatorname.iscsi
systemctl status iscsid  
```  

 ii. For Centos/RedHat OS, here are the steps to install iscsi packages -

 ```bash
 yum install iscsi-initiator-utils -y
```
To ensure that iscsi services are functioning correctly,
  check the output of the following commands -
  ```bash
  cat /etc/iscsi/initiatorname.iscsi
systemctl status iscsid
```

For any other operating systems, follow the [steps](https://docs.openebs.io/docs/next/prerequisites.html) mentioned for each of the operating systems/cloud providers.

3. Ensure that you have cluster admin-context before proceeding to Installation steps.

4. The cluster should be configured to run the containers in Privileged mode.

In a PMKFT environment, all you need to do is select the Privileged mode checkBox while creating a cluster from UI

![privilegedMode](https://github.com/KoolKubernetes/csi/blob/master/openEBS/images/privileged.png)


5. Disks that would form the storage Pool are mounted on the worker nodes. It's recommended to have a homogenous setup as far as possible in terms of Disk size, no. of disks etc.



### Installation Instructions

You can either choose to deploy OpenEBS components in the default namespace or in a custom namespace specifically for OpenEBS related pods etc. The latter is the recommended option.

1.  Create openebs namespace (Optional)

```bash
kubectl create ns openebs
```
2. Add the openEBS repo and then deploy the associated Helm chart.

```bash
helm repo add openebs https://openebs.github.io/charts
helm repo update
helm install --namespace openebs openebs openebs/openebs
```

This would install the openEBS pods with the default settings, you can modify the helm chart values by referring this [link](https://docs.openebs.io/docs/next/installation.html) (Custom Installation Mode Section)


### Verifying installation

1. Ensure that all the pods in `openebs` namespace are in a `Running` state

```bash
kubectl get pods -n openebs
```

Eg. Output
```bash
cstor-disk-pool-579u-559767cb7d-jp9t7               3/3     Running   0          6d5h
cstor-disk-pool-flf6-698b9fd475-n9968               3/3     Running   0          6d5h
cstor-disk-pool-t4qa-568c98dc94-vstmt               3/3     Running   0          6d5h
openebs-admission-server-66974b6ffd-87tjx           1/1     Running   0          6d5h
openebs-apiserver-6c4d9f4f9d-7smn2                  1/1     Running   0          6d5h
openebs-localpv-provisioner-bcd5b8b5-ngzq4          1/1     Running   0          6d5h
openebs-ndm-mnjpp                                   1/1     Running   0          6d5h
openebs-ndm-operator-778f9c566-wqfp4                1/1     Running   0          6d5h
openebs-ndm-r7wgg                                   1/1     Running   0          6d5h
openebs-ndm-x4plz                                   1/1     Running   0          6d5h
openebs-provisioner-57b7dfbc88-bttqw                1/1     Running   0          6d5h
openebs-snapshot-operator-69bb776f8-kz2ss           2/2     Running   0          6d5h
```
2.  Ensure that default storage classes have been created -

```bash
kubectl get sc
NAME                        PROVISIONER                                                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
openebs-device              openebs.io/local                                           Delete          WaitForFirstConsumer   false                  6d5h
openebs-hostpath            openebs.io/local                                           Delete          WaitForFirstConsumer   false                  6d5h
openebs-jiva-default        openebs.io/provisioner-iscsi                               Delete          Immediate              false                  6d5h
openebs-snapshot-promoter   volumesnapshot.external-storage.k8s.io/snapshot-promoter   Delete          Immediate              false
```
( Skipping the default storage class output)


3.  NDM daemon set creates a block device CR for each block devices that is discovered on the node with two exceptions

  i. The disks that match the exclusions in 'vendor-filter' and 'path-filter'

  ii. The disks that are already mounted in the node

  Following command lists the custom resource `blockdevice`  -

  ```bash
  kubectl get blockdevice -n openebs
NAME                                           NODENAME         SIZE          CLAIMSTATE   STATUS   AGE
blockdevice-11468d388afb4f901a2a0be368cf4ccd   10.128.146.28    10736352768   Claimed      Active   6d5h
blockdevice-e925dc2fb9192244050b3109ce521216   10.128.146.106   10736352768   Claimed      Active   6d5h
blockdevice-ea8eec503644998e92c4159ad0dfc4ed   10.128.146.145   10736352768   Claimed      Active   6d5h
```


### cStor

Background: cStor is the recommended option to get additional workload resiliency via OpenEBS. It provides enterprise-ready features such as synchronous data replication, snapshots, clones, thin provisioning of data, high resiliency of data, data consistency and on-demand increase of capacity or performance

The core function of cStor is to provide  iSCSI block storage using the locally attached disks/cloud volumes.

Additional details can be found [here](https://docs.openebs.io/docs/next/cstor.html).


### Deploy cStor Pools and the associated Storage Class.

You have to provide the list of blockdevices seen in the above output for creating a cStor storage pool.

A sample yaml file is already present in the ./openEBS/yaml folder of this repo. Please clone the repo for using it.  You'll have to edit the yaml file and add the blockdevices as seen in the command below -
```bash
 kubectl get blockdevice -o jsonpath='{ range .items[*]} {.metadata.name}{"\n"}{end}'
```

After updating the cstor.yaml with the relevant blockdevices observed in your environment, run the following command -

```bash
kubectl apply -f ./openEBS/yaml/cstor.yaml
```

PoolType selected is striped in this case. The available options are striped, mirrored, raidz and raidz2.

For further information on the type of Storage Pools, please refer the link [here](https://docs.openebs.io/docs/next/ugcstor.html#creating-cStor-storage-pools)


There's an example yaml available for deploying a cStor backed storage class so you can deploy PVs/PVCs associated with it.

The replicaCount in it is set to 1 currently, but you can tweak it as per your needs. If the application handles replication itself, then its recommended to keep the replicaCount to 1.

Run the following command to deploy the StorageClass -

```bash
kubectl apply -f ./openEBS/yaml/cstor.yaml
```


Once deployed you can use the new cstor storageClass to provision PVs and associated PVCs for deploying application workloads.
