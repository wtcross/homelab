#!/bin/bash
set -o nounset
set -o errexit

readonly STEP_KMS_PLUGIN_TAG="v0.16.0"
readonly STEP_CLI_GIT_TAG="v0.29.0"
readonly VERSION_IMAGE_TAG="ghcr.io/wtcross/step-kms-plugin:${STEP_KMS_PLUGIN_TAG}"
readonly LATEST_IMAGE_TAG="ghcr.io/wtcross/step-kms-plugin:latest"

podman build \
    --build-arg STEP_KMS_PLUGIN_TAG="${STEP_KMS_PLUGIN_TAG}" \
    --build-arg STEP_CLI_TAG="${STEP_CLI_GIT_TAG}" \
    --tag "${VERSION_IMAGE_TAG}" \
    --tag "${LATEST_IMAGE_TAG}" \
    -f ubi10.pkcs11.Containerfile \
    .

podman push "${VERSION_IMAGE_TAG}"
podman push "${LATEST_IMAGE_TAG}"
