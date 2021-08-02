## MinIO Operator for Kubernetes

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

This manifest creates minio-operator namespace, a certificate Issuer called as minio-operator and finally issues a certificate 'operator-tls-tls' from the issuer in the minio-operator namespace. Beyond this cert-manager also creates a secret with the same name that has the certificate, CA certificate and the private key file. extract the tls.crt and tls.key from the secret 'operator-tls-tls' and create a opaque type secret called as 'operator-tls' by running following commands:
```bash
kubectl create secret generic operator-tls --from-file=public.crt=./tls.crt --from-file=private.key=./tls.key
```
Validate the secret got created.
```bash
$ kubectl get secret
NAME                  TYPE                                  DATA   AGE
default-token-gvqwp   kubernetes.io/service-account-token   3      29m
operator-tls          Opaque                                2      13s
operator-tls-tls      kubernetes.io/tls                     3      24m
```

Install Min-IO operator
One can generate the Min-IO operator deployment manifest and apply in kubernetes with simple steps. 

# Deploy latest operator from [Min-IO](https://operator.min.io/)
```bash
wget https://github.com/minio/operator/releases/download/v4.1.3/kubectl-minio_4.1.3_linux_amd64 -O kubectl-minio
chmod +x kubectl-minio
mv kubectl-minio /usr/local/bin/
kubectl minio version
kubectl minio init -o > minio_4.1.3.yaml
kubectl apply -f minio_4.1.3.yaml
```

Optionaly you may deploy the operator from the manifest for Min-IO operator version 4.1.2 included in the repository.
```bash
kubectl apply -f operator/minio-operator-4.1.2.yaml
```

TLS can be enabled for the operator console with an cert-manager issued certificate and secret in the minio-operator namespace.
```bash
kubectl apply -f operator/console.yaml
```
This uses the same operator-tls-tls secret which was create for the minio-operator earlier. One may use a separate certificate for the console.
Patch the operator service to be of the type loadbalancer.

```bash
kubectl -n minio-operator patch svc console -p '{"spec": {"type": "LoadBalancer"}}'
```
```bash
$ kubectl get svc -n minio-operator
NAME       TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                         AGE
console    LoadBalancer   10.21.198.26   10.128.146.47   9090:30475/TCP,9443:30895/TCP   5d2h
operator   ClusterIP      10.21.175.75   <none>          4222/TCP,4233/TCP               5d2h
```
Operator console will be accessible as https://LB-IP:9443 e.g. https://10.128.146.47:9443

The secret can be found out with the following command:

```bash
kubectl minio proxy 
```

# Deploy Min-IO tenant with cert-manager issued certificate
we have provided a script to deploy a tenant with a cert-manager issued certificate. The script creates a tenant namespace, certificate issuer, issues certificate for the tenant and deploys the tenant with TLS.

```bash
tenant/tenant.sh tenant-name [tenant-namespace]
```
tenant-name is name of the tenant
tenant-namespace is set to tenant-name if the tenant-namespace is not specified. 

After a few minutes the the minio tenant will be ready and its console will be accessible over a ClusterIP type service called 'minio'

patch the tenant console service so that it can be accessed from the browser.
```bash
kubectl -n <tenant-name> patch svc minio -p '{"spec": {"type": "LoadBalancer"}}'
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
