#!/bin/bash
set -o nounset
set -o errexit

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
WORKSPACE_DIR=$( dirname "${SCRIPT_DIR}" )

source "${WORKSPACE_DIR}/.env.sh"

export ANSIBLE_GALAXY_SERVER_LIST=rh_automation_hub_certified,rh_automation_hub_validated,community
export ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_CERTIFIED_URL=https://console.redhat.com/api/automation-hub/content/published/
export ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_CERTIFIED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token

export ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_VALIDATED_URL=https://console.redhat.com/api/automation-hub/content/validated/
export ANSIBLE_GALAXY_SERVER_RH_AUTOMATION_HUB_VALIDATED_AUTH_URL=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
export ANSIBLE_GALAXY_SERVER_COMMUNITY_URL="https://galaxy.ansible.com/"

maybe_install_binaries() {
    local flightctl_path="${WORKSPACE_DIR}/.bin/flightctl"
    if [[ ! -f "${flightctl_path}" ]]; then
        curl -L https://github.com/flightctl/flightctl/releases/download/latest/flightctl-linux-amd64 -o "${flightctl_path}"
        chmod +x "${flightctl_path}"
    fi
}

maybe_install_os_deps() {
    local deps=$(uv run bindep --brief)
    if [[ $? -ne 0 ]]; then
        echo "${deps}" | xargs sudo dnf install -y
    fi
}

sync_uv_workspace() {
    uv python install && uv sync --all-packages
}

sync_ansible_content() {
    uv run ansible-galaxy collection install -r collections/requirements.yaml --force
}

pushd "${WORKSPACE_DIR}" &> /dev/null
sync_uv_workspace
maybe_install_os_deps
maybe_install_binaries

pushd ansible &> /dev/null
sync_ansible_content

popd &> /dev/null
popd &> /dev/null
