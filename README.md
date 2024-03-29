# mout.ch/k8s

Mirroring of https://gitlab.com/mout.ch/k8s

> :construction: **Working In Progress**: New version of this repo will be released frequently!

Code base for all deployments made on mout.ch k3s main cluster infrastructure.

### Argocd workflow

The root folder contains the argocd root application in charge of deploying all other applications in the cluster, including argocd themself. All applications (for the moment) are Helm charts that take a public Helm chart as a dependency in order to provide custom config values versioned by this repository.

### External services

The k3s cluster is part of mout.ch infrastructure where provides a consul and ceph cluster. The first is for creating a zero-trust service mesh (not in production for now, but soon), and the second provides a full resilient storage backend and is currently in use. All applications can also use the StorageClass created by ceph-csi-rbd provisioner to get a volume backed in ceph.

### Secrets

The secrets are stored in vault and then injected into k8s with [vault-secret-operator](https://github.com/ricoberger/vault-secrets-operator). These are essentially services external to the cluster that go through vault, such as tokens to access email or the gitlab registry. See [Access a private docker registry with vault-secret-operator's help ](https://blog.kelbert.fr/posts/acces-private-docker-registry-with-vault-secret-operator-s-help/).

```
helm upgrade --install --version 1.15.1 cilium cilium/cilium \
   --namespace cilium \
   --set operator.replicas=1 \
   --set l2announcements.enabled=true \
   --set kubeProxyReplacement=true \
   --set k8sClientRateLimit.qps=50 \
   --set k8sClientRateLimit.burst=100 \
   --set k8sServiceHost=192.168.14.21\
   --set k8sServicePort=6443 \
   --set l2announcements.leaseDuration=20s \
   --set l2announcements.leaseRenewDeadline=15s \
   --set l2announcements.leaseRetryPeriod=200ms \
   --set bgpControlPlane.enabled=false

```
