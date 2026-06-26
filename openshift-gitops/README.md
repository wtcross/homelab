# OpenShift GitOps

## Overview

This directory is where all OpenShift cluster configuration is managed.

## Directories

### [`clusters`](clusters)

Contains a directory for each cluster being managed. Within each cluster directory there is a Kustomize base and overlays 

### [`bootstrap`](bootstrap)

Kustomize base and overlays used to bootstrap a new cluster. There will be an overlay for each cluster that patches the project source repo url and path.

### [`apps`](apps)

These are ArgoCD Applications that are reused across clusters. They are managed separate from individual cluster config so that they can be versioned. This is to simplify promotion of Application versions across cluster environments.

### [`components`](components)

These are completely reusable Kustomize components for use in apps.
