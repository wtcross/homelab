#!/bin/bash
set -o nounset
set -o errexit

readonly STEP_CLI_VERSION="0.29.0"
readonly VERSION_IMAGE_TAG="ghcr.io/wtcross/step-cli:v${STEP_CLI_VERSION}"
readonly LATEST_IMAGE_TAG="ghcr.io/wtcross/step-cli:latest"

podman build \
    --build-arg STEP_CLI_VERSION="${STEP_CLI_VERSION}" \
    --tag "${VERSION_IMAGE_TAG}" \
    --tag "${LATEST_IMAGE_TAG}" \
    -f ubi10.Containerfile \
    .

podman push "${VERSION_IMAGE_TAG}"
podman push "${LATEST_IMAGE_TAG}"
