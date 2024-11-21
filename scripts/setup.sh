#!/bin/bash
set -o nounset
set -o errexit

readonly script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

install_os_dependencies() {
    sudo dnf install python3 pipx -y
}

install_poetry() {
    pipx install poetry
}

install_project_dependencies() {
    pushd "${script_dir}" &> /dev/null
    poetry install --no-root
    pushd "../ansible" &> /dev/null
    poetry run ansible-galaxy collection install -r collections/requirements.yml --force
    popd &> /dev/null
    popd &> /dev/null
}

install_os_dependencies
install_poetry
install_project_dependencies
