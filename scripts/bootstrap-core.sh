#!/bin/bash
set -o nounset
set -o errexit

LANG=C

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
WORKSPACE_DIR=$( dirname "${SCRIPT_DIR}" )
CATALOG_DIR="${WORKSPACE_DIR}/openshift-gitops/catalog"
CLUSTER_DIR="${WORKSPACE_DIR}/openshift-gitops/clusters"

SLEEP_SECONDS=30

echo "Installing initial secret for ESO"
kustomize build "${CLUSTER_DIR}/core/bootstrap/external-secrets" | oc apply -f -
oc create secret generic infra-secrets-reader-credentials --from-file="${WORKSPACE_DIR}/.priv/homelab-442320-c098cf369dbf.json" --namespace external-secrets

echo ""
echo "Installing OpenShift GitOps Operator."
kustomize build "${CLUSTER_DIR}/core/bootstrap/openshift-gitops-operator" | oc apply -f -

echo "Pause ${SLEEP_SECONDS} seconds for the creation of the openshift-gitops-operator..."
sleep "${SLEEP_SECONDS}"

echo "Waiting for operator to start"
until oc get deployment gitops-operator-controller-manager -n openshift-operators
do
  sleep 10;
done

echo "Waiting for openshift-gitops namespace to be created"
until oc get ns openshift-gitops
do
  sleep 10;
done

echo "Waiting for deployments to start"
until oc get deployment cluster -n openshift-gitops
do
  sleep 10;
done

echo "Waiting for all pods to be created"
deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n openshift-gitops
done

echo "Deploy OpenShift GitOps instance"
kustomize build "${CLUSTER_DIR}/core/bootstrap/openshift-gitops-instance" | oc apply -f -

# TODO: wait for successful deployment of the gitops instance

echo "Create the bootstrap Application"
kustomize build "${CLUSTER_DIR}/core/bootstrap/openshift-gitops-instance" | oc apply -f -
