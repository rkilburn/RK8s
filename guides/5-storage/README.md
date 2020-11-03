# Storage
It's time to add some state to the cluster in the form of Persistent Storage. For our cluster, we are going to use CEPH, and deploy it using the Rook CEPH Operator. 

The way a Storage Provider on Kubernetes works is as follows:
1. You create a PersistentVolume that has a StorageClass, or you create some Pods that have a template for a PersistentVolumeClaim. The PVC then requests the PersistentVolume to be created
2. The Provisioner for that StorageClass creates the volume in the storage system and registers it in Kubernetes as a PersistentVolume. 
3. The CSI Driver for that StorageClass then attaches the PersistentVolume to the Pod.

## 1. Deploy Rook Operator
First we need to apply the Custom Resource Definitions for Rook CEPH:
```bash
kubectl apply -f storage/0-common.yaml
```

Next up, we need to deploy the Operator. The Operator takes the CRDs and turns them into resources (including Pods, ConfigMaps and Secrets), within the cluster. In the YAML for the operator, you will see that we are setting Resource Requests & Limits and using the PriorityClasses we created earlier.

```bash
kubectl apply -f storage/1-operator.yaml
```

## 2. Deploy the CEPH Cluster
Now it's time to create our CEPH Cluster. Edit lines 222 onwards in `storage/2-cluster.yaml` and change your node names and disks. Then, apply the YAML and let the operator do the rest. This may take 5-10 minutes.

```bash
kubectl apply -f storage/2-cluster.yaml
kubectl get pods -n rook-ceph --watch

#Check Cluster Health
kubectl get CephCluster -n rook-ceph
```

## 3. Configure the Storage Classes
Once the CEPH Cluster reports `HEALTH_OK`, it's time to create a CEPH Block Pool and a Kubernetes Storage Class

```bash
kubectl apply -f storage/3-storageclass-ssd.yml
```

We can also use CEPH FS to provision Filesystem mounts that can be shared between multiple pods at the same time:
```
kubectl apply -f storage/3-storageclass-cephfs.yml
```

## 4. Create a PVC and Pod
Create a MySQL Server with persistent storage and check everything has been created:
```bash
kubectl apply -f ./mysql.yml

kubectl get pvc -n web-server
# NAME             STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS     AGE
# mysql-pv-claim   Bound    pvc-27a0daa9...   2Gi        RWO            ceph-block-ssd   5s

# Persistent Volumes are cluster wide resources
kubectl get pv
# NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS     REASON   AGE
# pvc-27a0daa9...   2Gi        RWO            Delete           Bound    web-server/mysql-pv-claim   ceph-block-ssd            103s
```

## 5. Challenge 1
Apply the following YAML which creates resources called  `storage-challenge-1`. Why does the Pod not create?

```bash
kubectl apply -f storage-challenge-1.yml
```

## 6. Challenge 2
Apply the following YAML which creates resources called  `storage-challenge-2`. Why does only one Pod get created?

```bash
kubectl apply -f storage-challenge-1.yml
```

## 7. Challenge 3
Apply the following YAML which creates resources called `storage-challenge-3`. Why are none of the Pods created and how can you make all three Pods run at the same time?

## 8. Tidy up time!
You made it! Hopefully your CEPH Cluster provisioned okay and you were able to try this out for yourself. A small amount of luck is generally needed, however once provisioned, CEPH is *infinitely* scalable.
```bash
kubectl delete -f .
```

