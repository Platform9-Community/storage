## Kubernetes Object Storage as s Service with MinIO.
# Running a secure cloud-native object storage with platform9 kubernetes and MinIO object storage

MinIO is a cloud native and cloud agnostic object storage solution. It is compatible with amazon S3.  Deploying a tenant to create object storage buckets is simple, fast and efficient with MinIO. MinIO gives storage software as a service experience.

MinIO can be used for a number of applications. It can greatly benefit as an object storage backend for artifact storage. From container registry to CICD minIO serves the purpose of s3 integration. As kubernetes is becoming popular in the fields of Artificial intelligence, machine learning and analytics, so are these applications getting benefited by storing files on object storage like MinIO. MinIO is suitable for such use cases as it gives the necessary performance on top of simple to consume and simple to integrate hardware configurations. 

Most of the kubernetes backup and recovery solutions are compatible with S3 that makes minIO a perfect fit for storing kubernetes backups as well. Hence commonly used backup solutions like velero and many more seamlessly integrate with MinIO.

MinIO can be integrated into kubernetes with ease. Maintenance is simple and easy. This eases the operational complexities. MinIO recently has come up with an operator that can manage multiple MinIO tenants in a kubernetes cluster. Operator has its own console from where one can manage the tenants. Tenants can be either provisioned via operator-console or via tenant manifest although all options for MinIO tenant are available in the tenant deployment via manifest. The tenant deployment on kubernetes is extremely easy. It supports integration with cert-manager using kubernetes TLS type secret to access the tenant and buckets via s3 client over HTTPS.

A tenant can be deployed into an application's microservice namespace. MinIO tenant runs as a stateful set with headless service in its namespace. Only one MinIO tenant is allowed per namespace. A tenant has its own console and service that can be used to visualize the tenant's performance via prometheus integration and manage the tenant features and S3 buckets. This reduces the operational complexities involved in managing the tenants. The tenant can be integrated with Active Directory or OpenID for authentication. By default the authentication is integrated with kubernetes opaque secret.

MinIO operator is simple to configure on kubernetes. The Operator has a console to manage tenants, License and visualize the storage used by minIO tenants. 

Another great feature is standard license costs only upto 10PBs and anything above 10PB is not charged. Similarly Enterprise license charges only upto 5PBs and anything above 5PB is not charged. The capacity report can be easily shared with MinIO from time to time.

# How to deploy minio on platform9 managed kubernetes:
One has to first deploy the minio-operator which then can deploy the minio tenant into a kubernetes namespaces. For production grade deployment it is recommended to integrate minio-Tenant with OpenID authentication and integrate Prometheus. Also leverage kubernetes TLS type secrets for accessing both the tenant and operator. Integration with cert-manager makes it simple to manage and rotate the TLS certificates for the minIO pods. MinIO tenant pods in the tenant stateful sets have to be restarted in the event of rotation of TLS certificate. 

As of now rotation of operator-tls certificate is manual so it should have a sufficiently longer lifespan acceptable to your organization.

One can install MinIO on platform9 managed kubernetes to quickly test MinIO with their choice of application following these steps:

# Prerequisites:

```bash
Kubernetes:
A decently sized platform9 managed kubernetes cluster.
Masters: minimum one node, three nodes are recommended for HA
Cluster nodes (Workers): Minimum four nodes
Node Sizing: 4VCPUs x 16GiBs per node
Disks: 1 x 100GiB for O.S. and 1 x 30GiB for CSI block storage on every worker node.
Persistent Storage: Any pre-configured kubernetes CSI on the cluster will be enough to allocate persistent volumes to the MinIO tenants. 
Kubernetes Version: 1.20
Platform9 management plane version: 5.2+
For a bare minimum configuration nodes with 2VCPUs and 4GB memory will be sufficient. One should be able to provision one or two min-IO tenants on such clusters.
On your on-premise setups configure metallb to access the min-IO operator and tenant consoles over the loadbalancer type service. MinIO tenants can also be exposed via an ingress controller.

Recommended software versions: 
Cert-manager: v1.4.1+
MinIO operator: 4.1.2+
```
# Note:
The deployment will work with any of the platform9 plans. You may login with a platform9 [free tier](https://platform9.com/signup/) account to spin up a free kubernetes cluster on your private or public cloud infrastructure.
Please refer to the platform9 community [page](https://github.com/Platform9-Community/csi/tree/master/rook) in order to setup up a persistent storage with rook on platform9 managed kubernetes.

# Deploy Rook-ceph CSI on your cluster
If you do not have an existing CSI configured, install [rook](https://github.com/Platform9-Community/csi/tree/master/rook) CSI on your platform9 cluster. After the rook-ceph cluster gets configured apply the manifest provided in this [repository](https://raw.githubusercontent.com/Platform9-Community/storage/master/minio/rook/4-storageclass-immediate.yaml) to deploy the storage class. If this storageclass fails to allocate volumes during tenant creation, an alternate storage class yaml is also provided in the same [repository](https://github.com/Platform9-Community/storage/blob/master/minio/rook/4-storageclass.waitforfirstconsumer.yaml).

Create the storage class
```bash
kubectl apply -f rook/4-storageclass-immediate.yaml
```
Validate the Storage Class has been created and has been set as default.
```bash
kubectl get sc
NAME                        PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   4d3h
```


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
Install with kubectl and manifest provided with the repository:
```bash
kubectl apply -f  cert-manager/cert-manager-v1.4.1.yaml
```

In order to install the latest cert-manager version with kubectl:
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

With cert-manager one can create certificate issuer under namespace as well as at the cluster level. Here we are going to keep the inssuer's scope specific to the namespace.

# Deploy minio-operator
Min-IO operator requires a kubernetes opaque type secret called as 'operator-tls'. This secret can be created from the private key file and certificate issued from cert-manager. 

With cert-managet first create a Issuer and issue a certificate. 
```bash
kubectl apply -f operator/operator-tls-tls.yaml
```

This manifest creates minio-operator namespace, a certificate Issuer called as minio-operator and finally issues a certificate 'operator-tls-tls' from the issuer in the minio-operator namespace. Beyond this cert-manager also creates a secret with the same name 'operator-tls-tls' which has the certificate, CA certificate and the private key file. extract the tls.crt and tls.key from the secret 'operator-tls-tls' and create a opaque type secret named as 'operator-tls' by running following command:
```bash
kubectl create secret generic operator-tls --from-file=public.crt=./tls.crt --from-file=private.key=./tls.key
```

Validate the secrets has got created.
```bash
$ kubectl get secret
NAME                  TYPE                                  DATA   AGE
default-token-gvqwp   kubernetes.io/service-account-token   3      29m
operator-tls          Opaque                                2      13s
operator-tls-tls      kubernetes.io/tls                     3      24m
```
The 'operator-tls-tls.yaml' provided in this reposiory has SAN fields for both operator and it's console.

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
# Deploy MinIO operator provided in the reposiotry
Optionaly one may deploy the operator from the manifest for Min-IO operator version 4.1.2 included in the repository.
```bash
kubectl apply -f operator/minio-operator-4.1.2.yaml
```

TLS can now be enabled for the operator console with an cert-manager issued certificate and secret in the minio-operator namespace.
```bash
kubectl apply -f operator/console.yaml
```
This uses the same 'operator-tls-tls' secret which was create for the minio-operator earlier. Ooptionaly one may also issue a separate certificate for the console.

Patch the operator service to be of the type loadbalancer.
```bash
kubectl -n minio-operator patch svc console -p '{"spec": {"type": "LoadBalancer"}}'
```
validate the service has got the IP address from the metallb or the cloud provider.
```bash
$ kubectl get svc -n minio-operator
NAME       TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                         AGE
console    LoadBalancer   10.21.198.26   10.128.146.47   9090:30475/TCP,9443:30895/TCP   5d2h
operator   ClusterIP      10.21.175.75   <none>          4222/TCP,4233/TCP               5d2h
```

The operator UI login secret key can be found out with the following command:

```bash
kubectl minio proxy 
```

Operator console will be accessible as https://LB-IP:9443 e.g. https://10.128.146.47:9443
![minio-operator-console](https://github.com/Platform9-Community/storage/blob/master/minio/images/minio-operator-console.png)

# Deploy Min-IO tenant with cert-manager issued certificate
we have provided a script to deploy a tenant with a cert-manager issued certificate. The script creates a tenant namespace, certificate issuer, issues certificate for the tenant and deploys the tenant with TLS.

```bash
tenant/tenant.sh tenant-name [tenant-namespace]
```
tenant-name is name of the tenant (Mandatory field)
tenant-namespace is set to tenant-name if the tenant-namespace is not specified. 

After a few minutes the the minio tenant will be ready and its console will be accessible over a ClusterIP type service called 'minio'

patch the tenant console service so that it can be accessed from the browser.
```bash
kubectl patch svc minio -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc tenant-name-console -p '{"spec": {"type": "LoadBalancer"}}'
```

Validation:
```bash
kubectl get pods,svc,secret -n tenant6
NAME                                   READY   STATUS    RESTARTS   AGE
pod/tenant6-console-755fcf44b5-568vw   1/1     Running   0          4d1h
pod/tenant6-console-755fcf44b5-z8259   1/1     Running   0          4d1h
pod/tenant6-ss-0-0                     1/1     Running   0          4d1h
pod/tenant6-ss-0-1                     1/1     Running   0          4d1h
pod/tenant6-ss-0-2                     1/1     Running   0          4d1h
pod/tenant6-ss-0-3                     1/1     Running   0          4d1h

NAME              TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE
minio             LoadBalancer   10.21.80.216    10.128.146.49   443:32037/TCP    5d6h
tenant1-console   LoadBalancer   10.21.118.112   10.128.146.19   9443:31226/TCP   5d6h
tenant1-hl        ClusterIP      None            <none>          9000/TCP         5d6h

NAME                             TYPE                                  DATA   AGE
secret/default-token-56xzg       kubernetes.io/service-account-token   3      4d1h
secret/operator-tls              Opaque                                1      4d1h
secret/operator-webhook-secret   Opaque                                3      4d1h
secret/tenant6-cert              kubernetes.io/tls                     3      4d1h
secret/tenant6-console-secret    Opaque                                4      4d1h
secret/tenant6-creds-secret      Opaque                                2      4d1h
```
The tenant console is vizualized as follows:

![minio-tenant-console](https://github.com/Platform9-Community/storage/blob/master/minio/images/minio-tenant-console.png)

References:
https://github.com/minio/operator