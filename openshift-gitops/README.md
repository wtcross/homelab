# Lab GitOps

Steps:
- 1. Run `oc apply -k clusters/core.lab.cross.solutions/bootstrap` to bootstrap the cluster with the OpenShift GitOps operator
- 2. Partition whichever NVMe drive was not used for installation with one XFS partition and one unformatted partition
- 3. Run `oc apply -k clusters/core.lab.cross.solutions/platform-setup`
