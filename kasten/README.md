# Backup and Restore Kubernetes  stateful/stateless applications using Kasten


Kasten is an enterprise grade backup and recovery tool specifically focussed on cloud-native applications and is completely database aware. You can find out more about it [here](https://www.kasten.io/)
The trial version of Kasten supports upto 10 nodes.

There are certain prerequisites needed for the source cluster so that Kasten can successfully take CSI snapshots. This is particularly helpful where file level backups cannot work like DBs etc.

The basic workflow being followed is -

1. Ensure prerequisites are met on the source cluster. Install Kasten on the source cluster and the destination cluster.
2. Create the backup policy and Cloud profiles (credentials etc for the remote Object storage where the backup would be placed)
3. Create the backup along with export option selected for the application that you want to backup.
4. Once the backup completes, create an import policy and cloud profile in the destination cluster and start the restore.

## Prerequisites
1. Ensure Helm is installed. It can either be Helm 2 or Helm 3. Preferable is Helm 3 as it simplifies the installation process

1. Make sure to enable the VolumeSnapshotDataSource feature gate on your Kubernetes cluster API server yaml file.

```bash
--feature-gates=VolumeSnapshotDataSource=true
```

For Platform9 Managed Kubernetes (PMK) and Platform9 Managed Kubernetes Free Tier (PMKFT) clusters, here are the steps to add the feature gate to api server container

Browse to the location - cd `/opt/pf9/pf9-kube/conf/masterconfig/base` and edit the `master.yaml` to add the following line under the section `command` for the `apiserver` container. Ensure that the yaml syntax is maintained.

```bash
- "--feature-gates=VolumeSnapshotDataSource=true"
```

After editing the master.yaml, stop the pf9-kube process and start it using the following commands on the master servers as it will restart the api-server component needed for the above flags to take effect.
```bash
/etc/init.d/pf9-kube stop
```
Let the above command complete, and then issue the following command -
```bash
/etc/init.d/pf9-kube start
```

This has to be done on all the masters in the clusters on one by one basis.

3. Ensure that SnapshotClass exists in your Kubernetes cluster as its needed by Kasten for triggering Snapshots before backing up to a remote Object Storage. You can check it by running the following command

```bash
kubectl get storageclass
```

Here's an example of the output -

```bash
kubectl get storageclass
NAME                        PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   16h
```

Before moving forward, please ensure that you are able to create a snapshot and restore it as well as this functionality is critical for Kasten to work successfully. If you are you using Rook-Ceph as the storage backend, please check the KoolKubernetes [link](https://github.com/KoolKubernetes/csi/tree/master/rook) for Rook which provides steps to enable CSI snapshot functionality

In this example, I'll be backing up a statefulset from my baremetal rook cluster to a minikube cluster locally.

4. Another prerequisite is to have a default storage class in your environment so that Kasten pods can spawn successfully.

5. The last prerequisite is that the VolumeSnapshotClass that you would like to use Kasten with should have the annotation
```bash
k10.kasten.io/is-snapshot-class: "true"
```

It could be done using the command -

```bash
kubectl patch volumesnapshostclass <snapshotclassName> -p '{"metadata": {"annotations":{"k10.kasten.io/is-snapshot-class: "true"}}}'
```


### Installing Kasten


1. The first step is to ensure that kasten prerequisites are met.

This can be done by running following command -

```bash
curl https://docs.kasten.io/tools/k10_primer.sh | bash
```

(More details can be found [here](https://docs.kasten.io/latest/install/requirements.html))

If things look good the output should look like the following screenshot



Please ensure that all the prerequisites are seen in an `OK` state before proceeding.
The major ones and the most problematic can be ensuring that storageClass and volumeSnapshotClass prerequsites are metadata

![prerequisites_screenshot](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/prereqs.png)



2. Once all the prerequisites are met, please proceed with the installation of Kasten on the source cluster.

   i. Create the kasten-io namespace ( You can choose to have a custom namespace as well)

   ```bash
   kubectl create namespace kasten-io
   ```
   ii.  Add the Kasten repo to Helm

   ```bash
   helm repo add kasten https://charts.kasten.io/
   ```
  iii.
#### Helm 3
  ```bash
  helm install k10 kasten/k10 --namespace=kasten-io
  ```
#### Helm 2

  Additional steps are needed to setup  a service account that has a cluster-admin role binding. Without the proper binding, you may run into install errors. If this happens, your can run the following
  add a service account within a namespace to segregate tiller
  ```bash
  kubectl --namespace kube-system create sa tiller
  ```
  create a cluster role binding for tiller
  ```bash
   kubectl create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller
  ```

  initialize helm within the tiller service account
```bash
helm init --service-account tiller
```
```bash
kubectl --namespace kube-system create sa tiller
```
   create a cluster role binding for tiller
```bash
   kubectl create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller
```
initialize helm within the tiller service account
```bash
helm init --service-account tiller
```
    After the above steps have completed, run the installation

    ```bash
helm install kasten/k10 --name=k10 --namespace=kasten-io
    ```


### Validating Kasten installation

Verify all the kasten pods have come up successfully by running the following command -

```bash
 kubectl get pods --namespace kasten-io --watch
 ```

Ensure that all the pods in the namespace have come up successfully.
```
kubectl get pods -n kasten-io
NAME                                  READY   STATUS    RESTARTS   AGE
aggregatedapis-svc-785c54df6b-xdnhf   1/1     Running   0          24h
auth-svc-8688697df9-m989s             1/1     Running   0          24h
catalog-svc-8545b48d5f-qvjvd          2/2     Running   0          24h
config-svc-9dccd9557-8sm24            1/1     Running   0          24h
crypto-svc-6b8cb77df-f9rhx            1/1     Running   0          24h
dashboardbff-svc-594cdbbc79-rwtbl     1/1     Running   0          24h
executor-svc-9b98b89d7-8xntb          2/2     Running   0          24h
executor-svc-9b98b89d7-ksfcx          2/2     Running   0          24h
executor-svc-9b98b89d7-mm8bv          2/2     Running   0          24h
frontend-svc-6d8c8d8bb5-9mnw5         1/1     Running   0          24h
gateway-58fdcf4db7-vxq6h              1/1     Running   0          24h
jobs-svc-785f9c4875-g6lgt             1/1     Running   0          24h
kanister-svc-5bbff5877c-kh8tz         1/1     Running   0          24h
logging-svc-658599b796-pdvth          1/1     Running   0          24h
metering-svc-6bf8f66d8b-vgcks         1/1     Running   0          24h
prometheus-server-78f5cb586c-mz2j9    2/2     Running   0          24h
state-svc-84496c5585-6fbqs            1/1     Running   0          24h
```



**IMPORTANT NOTE**: If you only want to backup and restore unidirectionally from source cluster to destination cluster, you don't need CSI snapshot functionality on the destination cluster. If you want biredirectional backup restore functionality, you'll have to ensure that destination cluster also meets all the prerequisites mentioned earlier. In this example, I am only demonstrating unidirectional backup and restore.


Perform the above steps to install Kasten on destination cluster as well.


### Installing  a test mysql application (Optional)

I am installing this test mysql application to demonstrate backup and restore functionality

1. Create a namespace called mysql-test
```bash
kubectl create namespace mysql-test
```

2. Add stable helm repo to your helm installation if its not already present.
```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
```

3.  Install mysql helm chart
```bash
 helm install --name mysql-t stable/mysql
 ```

4. Ensure that mysql pod has come up successfully and is in a running state.

 ```bash
 kubectl get pods -n mysql-test
NAME                       READY   STATUS    RESTARTS   AGE
mysql-t-58c7bd8c7c-9wfsc   1/1     Running   0          24h
```

5. Now, let's exec into the mysql pod and inject some data so we can test the restore of it as well.
```bash
kubectl exec -it -n mysql-test $(kubectl get pods -n mysql-test  -o=jsonpath='{.items[0].metadata.name}') -- bash
```
6.  Now, lets  login to mysql application. and create a database followed by a table and inject some data.
```bash
mysql -u root --password=$(env | grep -i  MYSQL_ROOT_PASSWORD | cut -d '=' -f 2)
```
7. You should see a msyql prompt on the terminal. Run the following commands sequentially.
```bash
create database pf9;
use pf9;
create table products ( productname varchar(200), version float);
insert into products Values( "Managed Kubernetes", 4.5);


8. Verify that the table has been populated by running the command -
```bash
 select * from products;
```
You should see a similar output

```bash
mysql> select * from products;
+--------------------+---------+
| productname        | version |
+--------------------+---------+
| Managed Kubernetes |     4.5 |
+--------------------+---------+
1 row in set (0.00 sec)
```


###  Accessing the Kasten UI

Kasten has a really intuitive interface and you can access it by running the command

```bash
kubectl --namespace kasten-io port-forward service/gateway 8080:8000
```

You can now login to the UI by browsing to this [link](http://127.0.0.1:8080/k10/#/). You should see a UI like the screenshot below.





### Configuring Kasten for Backup

1. Click on the settings tab highlighted in the screenshot

![Kasten UI](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/kasten_ui.png)


2. Click on the location profiles and enter credentials for any of the public cloud vendors where remote object storage can be uesd. I am showing Amazon S3 as an example. Ensure that the bucket  is already created in that region and the credentials entered have Read/Write access to it.

![New Profile](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/new_profile.png)

Click on validate and save and ensure that the location profile has been created successfully.
This is the remote object storage that would be used to backup the data of your applications running on your source cluster.

![Location Profile](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/location_profile.png)

3. Let's enable K10 Disaster recovery in the next steps. Go to the Settings tab and select K10 Disaster Recovery -> Enable K10 DR.
Select the Location Profile created in Step 2.

![Enable DR](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/enable_dr.png)



4. Next, we'll create a backup policy that would be responsible for backing up your application.
Goto Dashboard and select Polices. On the policies  page, you'll observe "Create a new policy" button.

  Enter the name of the policy. Select action as Snapshot, Action Frequency as Daily and one of the most important section is "Enable Backups via Snapshot Exports".This functionality exports the backup to the remote object storage ( S3 in this case) which can be used for restore then.

![new-policy](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/new_policy.png)

  Scroll down and selection the application by name, in this case its mysql-test then select the Location Profile created and click on Create policy

![new-policy-cont](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/new_policy_1.png)

Once the backup policy has been created, you should now be able to see the application as compliant and the backup policy can be triggered.

![compliant application](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/applications.png)

4. On the policies page, Click on the "Show Import Details" button so we can store the encoded text that would be required while creating the Import policy on the destination clusters

![compliant application](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/importData.png)

4. Let's trigger the policy now by clicking on Policies -> select "run once"


![policy_trigger](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/policy_trigger.png)

5. You can track the progress of the backup by going back to the Dashboard. Here's a screenshot where backup completed and the subsequent Export operation is underway.

![backup_export](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/backup_export.png)


6. Once the backup is complete, ensure that the AWS bucket has the data populated.

### Configuring Kasten for restore

Switch to the destination cluster and ensure that Kasten has been installed successfully. Also, ensure that you have atleast one storage class configured.

1.  Access the UI as mentioned in the earlier section, you might have to change the local port from 8080 to 8081 in port-forward command.
```#!/usr/bin/env bash
kubectl --namespace kasten-io port-forward service/gateway 8081:8000
```

Now the UI should be accessible on the following link - http://127.0.0.1:8081/k10/#

2. Create the Import Location Profile using the same creds and the same bucket as in the earlier section.

3. Now, we'll be creating the Import Policy so we can run the Restore job. Selecting restore after import deploys the restored application too. There are other options that have been specified in the screenshot along with their explanations.

![import_policy](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/import_policy.png)


There's one more important option "Apply Transforms to restored resources" which is  needed if the storageclasses from source and destination clusters differ( which is most likely the case)

Select Apply transform and click on "Add New Transform"

![applytranformCheckbox](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/applytranformCheckbox.png)

4. This would open up a new dialog box called "New Transform". Click on "Use Example" and select "Change StorageClass"

![new_transform](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/NewTransform.png)


Click on change storageClass and edit the name of the storage class present on the destination cluster. ( In my case , as its a minikube cluster, the storage class name is standard)

![edit](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/edit.png)


Enter the name of the storage class in double-quotes -> Select Edit Operation and click on Create Transform.

![CreateTransform](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/CreateTransform.png)

5. Finally, after the tranformation step, you would see a text box for "Config Data for Import", Over here you'll have to enter the copied encoded text from the policy creation step. Click on Create policy to finish the policy creation.

6. Click on "run once" option to run the Import policy once. This triggers the Import from the Restorepoint first. This is nothing but fetching data from the remote object storage, S3 in this case. Its followed by the restore job that restores the application on the destination cluster.


![ImportJob](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/importJob.png)

![RestoreJob](https://github.com/KoolKubernetes/backup/blob/master/kasten/images/restore.png)


7. Once the jobs complete, you'll find the newly created namespace and the mysql pod in that namespace. Lets verify if the data has been actually restored. Run the following commands on the destination cluster -

```#!/usr/bin/env bash
kubectl exec -it -n mysql-test $(kubectl get pods -n mysql-test  -o=jsonpath='{.items[0].metadata.name}') -- bash
mysql -u root --password=$(env | grep -i  MYSQL_ROOT_PASSWORD | cut -d '=' -f 2)
use pf9;
select * from products;
```

You should see either the test data or the application data in case you chose a different application for backup.
