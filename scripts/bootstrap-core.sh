#!/bin/bash
set -o nounset
set -o errexit

LANG=C

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
WORKSPACE_DIR=$( dirname "${SCRIPT_DIR}" )
GITOPS_DIR="${WORKSPACE_DIR}/openshift-gitops"

SLEEP_SECONDS=30

if [[ -z "$GCP_CREDENTIAL_PATH" ]]; then
    echo "Must provide GCP_CREDENTIAL_PATH in environment" 1>&2
    exit 1
fi


echo "Installing initial secret for ESO"
oc get namespace external-secrets &> /dev/null || oc create namespace external-secrets
oc get secret cluster-secrets-reader-credentials --namespace external-secrets &> /dev/null || oc create secret generic cluster-secrets-reader-credentials \
  --from-file=secret-access-credentials="${GCP_CREDENTIAL_PATH}" \
  --namespace external-secrets

echo ""
echo "Installing OpenShift GitOps Operator."
oc apply -k "${GITOPS_DIR}/components/openshift-gitops/operator/overlays/default"

echo "Pause ${SLEEP_SECONDS} seconds for the creation of the openshift-gitops-operator..."
sleep "${SLEEP_SECONDS}"

echo "Waiting for operator to start"
until oc get deployment openshift-gitops-operator-controller-manager -n openshift-gitops-operator
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
deployments=(cluster openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n openshift-gitops
done

echo "Deploy OpenShift GitOps instance"
oc apply -k "${GITOPS_DIR}/components/openshift-gitops/instance/overlays/acm-2.15-hub"

until oc get argocd openshift-gitops -n openshift-gitops -o jsonpath='{.status.phase}' | grep -q Available
do
  sleep 10;
done

echo "Create the bootstrap Application"
oc apply -k "${GITOPS_DIR}/bootstrap/overlays/lab"
