#!/bin/bash
set -o nounset
set -o errexit

readonly script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
readonly project_dir=$( dirname "${script_dir}" )

pushd "${project_dir}" &> /dev/null

sudo dnf install -y uv
uv python install
uv venv --allow-existing
uv sync


pushd ansible &> /dev/null

uv run ansible-galaxy collection install -r collections/requirements.yaml --force
uv run ansible-galaxy role install -r galaxy-roles/requirements.yaml -p galaxy-roles --force

popd &> /dev/null
popd &> /dev/null

# TODO: set up vaultwarden CLI for use with ansible lookup plugin for bitwarden
