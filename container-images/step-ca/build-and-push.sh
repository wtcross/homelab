#!/bin/bash
set -o nounset
set -o errexit

readonly STEP_CA_VERSION="0.29.0"
readonly STEP_CLI_VERSION="0.29.0"

readonly VERSION_IMAGE_TAG="ghcr.io/wtcross/step-ca:v${STEP_CA_VERSION}"
readonly LATEST_IMAGE_TAG="ghcr.io/wtcross/step-ca:latest"

podman build \
    --build-arg STEP_CA_VERSION="${STEP_CA_VERSION}" \
    --build-arg STEP_CLI_VERSION="${STEP_CLI_VERSION}" \
    --tag "${VERSION_IMAGE_TAG}" \
    --tag "${LATEST_IMAGE_TAG}" \
    -f ubi10.pkcs11.Containerfile \
    .

podman push "${VERSION_IMAGE_TAG}"
podman push "${LATEST_IMAGE_TAG}"
