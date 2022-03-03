# mout.ch/k8s

Mirroring of https://gitlab.com/mout.ch/k8s

> :construction: **Working In Progress**: New version of this repo will be released frequently!

Code base for all deployments made on mout.ch k3s main cluster infrastructure.

### Argocd workflow

The root folder contains the argocd root application in charge of deploying all other applications in the cluster, including argocd themself. All applications (for the moment) are Helm charts that take a public Helm chart as a dependency in order to provide custom config values versioned by this repository.

### External services

The k3s cluster is part of mout.ch infrastructure where provides a consul and ceph cluster. The first is for creating a zero-trust service mesh (not in production for now, but soon), and the second provides a full resilient storage backend and is currently in use. All applications can also use the StorageClass created by ceph-csi-rbd provisioner to get a volume backed in ceph.

### Legacy code

Some directory present here are still from a legacy use of the cluster and they will be removed soon.
