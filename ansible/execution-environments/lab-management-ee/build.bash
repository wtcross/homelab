#!/bin/bash
set -o nounset
set -o errexit

readonly SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
readonly PROJECT_DIR=$( dirname "${SCRIPT_DIR}" )
readonly EE_DIR=$( dirname "${PROJECT_DIR}" )
readonly WORKSPACE_DIR=$( dirname "${EE_DIR}" )

readonly REQUIRED_IN_PATH=( podman uv )

readonly EE_NAME=$( basename "${SCRIPT_DIR}" )
readonly EE_REGISTRY_HOST="aap.apps.core.lab.cross.solutions"
readonly EE_IMAGE_TAG="${EE_REGISTRY_HOST}/${EE_NAME}"

source "${WORKSPACE_DIR}/.env.sh"

ensure_deps_in_path() {
    for i in "${REQUIRED_IN_PATH[@]}"
    do
        if ! which ${i} >/dev/null; then
            echo ${i} must be in PATH
            exit 1
        fi
    done
}

ensure_podman_auth() {
    podman login --get-login "${EE_REGISTRY_HOST}" > /dev/null
}

write_uv_ee_requirements() {
    uv --quiet export \
        --no-annotate --no-header --no-hashes \
        --only-group ee \
        --format requirements-txt \
        --output-file "${SCRIPT_DIR}/requirements.txt"
}

build_ee() {
    ansible-builder build \
        --container-runtime=podman \
        --tag "${EE_IMAGE_TAG}" \
        --build-arg ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_CERTIFIED_TOKEN="${ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_CERTIFIED_TOKEN}" \
        --build-arg ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_VALIDATED_TOKEN="${ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_VALIDATED_TOKEN}"
}

push_ee() {
    podman push --tls-verify=false "${EE_IMAGE_TAG}"
}

cleanup() {
    rm -rf "${SCRIPT_DIR}/context" "${SCRIPT_DIR}/requirements.txt"
}

ensure_deps_in_path && ensure_podman_auth
write_uv_ee_requirements && build_ee && push_ee && cleanup
