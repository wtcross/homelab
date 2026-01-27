#!/bin/bash
set -o nounset
set -o errexit

readonly STEP_CA_GIT_TAG="v0.29.0"
readonly STEP_CLI_GIT_TAG="v0.29.0"

readonly VERSION_IMAGE_TAG="ghcr.io/wtcross/step-ca:${STEP_CA_GIT_TAG}"
readonly LATEST_IMAGE_TAG="ghcr.io/wtcross/step-ca:latest"

podman build \
    --build-arg STEP_CA_GIT_TAG="${STEP_CA_GIT_TAG}" \
    --build-arg STEP_CLI_GIT_TAG="${STEP_CLI_GIT_TAG}" \
    --tag "${VERSION_IMAGE_TAG}" \
    --tag "${LATEST_IMAGE_TAG}" \
    -f ubi10.pkcs11.Containerfile \
    .

podman push "${VERSION_IMAGE_TAG}"
podman push "${LATEST_IMAGE_TAG}"
