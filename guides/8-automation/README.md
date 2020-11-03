# Automation

We finally have our cluster running exactly how we like it. We have our users, namespaces, networking, scheduling and storage all configured correctly and we move on our lives. 

However, as with everything, we are gonna need to make a change now and again for things like new users and namespaces, or increasing a namespaces quotas. Wouldn't it be smashing if we could edit our cluster configuration on Git and have it automagically applied to the cluster. Lets do it!

## 1. Push this repository to Git
Using your favourite source control platform, push this repository to it. 

## 2. Create a new keypair
Create a new set of keys to authenticate to Git with using the following command:
```bash
ssh-keygen -f rk8s_rsa
# Dont add a passphrase
```
Upload the public key to your Git repos access keys with Read/Write access

## 3. Create a namespace for Flux
As part of isolating services, create a new namespace specifically for Flux.
```bash
kubectl create namespace kube-flux
```

## 3. Create a secret with the private key
Flux needs the private key in order to talk to Git. Put it into a secret in the `kube-flux` namespace using the following command. The key in which the key will be stored is `identity` as that is the file that Flux uses (check out the flux.yml file to see how and where this is mounted).
```bash
kubectl create secret generic flux-git-key --from-file=identity=rk8s_rsa -n kube-flux
```

## 4. Configure Flux
Edit the Flux command line parameters to specify what folders in this repository you would like to sync. All subdirectories of the folders you specificy will also be included.

```bash
nano automation/flux.yml
```

## 5. Deploy Flux
Deploy Flux (and its dependency MemcacheD)
```bash
kubectl apply -f automation/
```

## 6. Watch Flux complete it's first sync
```bash
kubectl logs -f deployment/fluxcd -n kube-flux
```

## 7. Look at the Commits
You will see that Flux updates the Git repo with a tag to show which commit the cluster is currently synced with

## 8. Make a change!
Create a new namespace or user, make a change to the ResourceQuotas or LimitRanges, or update the number of replicas of a deployment in `applications`.

Commit the change, and push to source control and watch flux apply the change.
