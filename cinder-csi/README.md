# CSI with cinder-csi on Openstack/PMO Platform9 Managed Kubernetes Clusters

This document uses CSI Cinder Driver and  PMK 5.0 as a reference, the objective is to provide a storage class based on cinder volumes using CSI cinder for Kubernetes Clusters deployed in Openstack/PMO.

The path we are going to follow is based on using the manifest provided by the cloud-provider-openstack repo and not in the helm charts that are available.

 

In your master node or from the node you have access to the cluster clone the following repository.

```git clone https://github.com/kubernetes/cloud-provider-openstack.git```
 

Explore the folder and locate the manifest files for CSI-cinder, you will need to prepare the secret which contains the rc file of our openstack cloud, in this case I will use the following file converted to base64

```
[root@master00 cinder-csi-plugin]# cat cloud.conf
[Global]
username = YOUR_USER
password = YOUR_PASSWORD
domain-name = default
auth-url = https://YOUR_DU_URL/keystone/v3
tenant-id = YOUR_TENANT_ID
region = YOUR_REGION
``` 

Cypher your file with base64 encryption so it can be use as a secret.
```
cat cloud.conf | base64 |tr -d '\n'
W0dsb2JhbF0KdXNlcm5hbWUgPSBZT1VSX1VTRVIKcGFzc3dvcmQgPSBZT1VSX1BBU1NXT1JECmRvbWFpbi1uYW1lID0gZGVmYXVsdAphdXRoLXVybCA9IGh0dHBzOi8vWU9VUl9EVV9VUkwva2V5c3RvbmUvdjMKdGVuYW50LWlkID0gWU9VUl9URU5BTlRfSUQKcmVnaW9uID0gWU9VUl9SRUdJT04Kpf9-0102
```
Insert the contents of your secret in the csi-secret-cinderplugin.yaml file 

```
[root@master00 cinder-csi-plugin]# cat csi-secret-cinderplugin.yaml
# This YAML file contains secret objects,
# which are necessary to run csi cinder plugin.

kind: Secret
apiVersion: v1
metadata:
  name: cloud-config
  namespace: kube-system
data:
  cloud.conf: W0dsb2JhbF0KdXNlcm5hbWUgPSBZT1VSX1VTRVIKcGFzc3dvcmQgPSBZT1VSX1BBU1NXT1JECmRvbWFpbi1uYW1lID0gZGVmYXVsdAphdXRoLXVybCA9IGh0dHBzOi8vWU9VUl9EVV9VUkwva2V5c3RvbmUvdjMKdGVuYW50LWlkID0gWU9VUl9URU5BTlRfSUQKcmVnaW9uID0gWU9VUl9SRUdJT04Kpf9-0102
``` 

Create the secret by applying the cs-secret-cinderplugin.yaml file This should create a secret name cloud-config in kube-system namespace.

```kubectl create -f manifests/cinder-csi-plugin/csi-secret-cinderplugin.yaml```
 

Apply the rest of the manifest to deploy csi-cinder controller and plugins, This creates a set of cluster roles, cluster role bindings, and statefulsets etc to communicate with openstack(cinder). For detailed list of created objects, explore the yaml files in the directory. 

``kubectl -f manifests/cinder-csi-plugin/ apply``
 
You should make sure following similar pods are ready before proceed creating pvcs.

```
csi-cinder-controllerplugin-0             6/6     Running     6          8d
csi-cinder-nodeplugin-4w6w6               3/3     Running     3          8d
csi-cinder-nodeplugin-gk5nf               3/3     Running     3          8d
```

To get information about CSI Drivers running in a cluster -

```
$ kubectl get csidrivers.storage.k8s.io
NAME                       CREATED AT
cinder.csi.openstack.org   2019-07-29T09:02:40Z
```


For the testing section so far only the dynamic provisioning and resize volume in-use have been tested, but only dynamic provisioning has worked properly.

### Dynamic Volume Provisioning

Please deploy the nginx test pod that contains a PVC object as described in the following link, to validate the Dynamic Volume Provisioning functionality.

https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/cinder-csi-plugin/examples.md#dynamic-volume-provisioning