#!/bin/bash
set -o nounset
set -o errexit

readonly GIT_TAG="v0.16.0"
readonly VERSION_IMAGE_TAG="ghcr.io/wtcross/step-kms-plugin:${GIT_TAG}"
readonly LATEST_IMAGE_TAG="ghcr.io/wtcross/step-kms-plugin:latest"

podman build \
    --build-arg TAG="${GIT_TAG}" \
    --tag "${VERSION_IMAGE_TAG}" \
    --tag "${LATEST_IMAGE_TAG}" \
    -f ubi10.Containerfile \
    .

podman push "${VERSION_IMAGE_TAG}"
podman push "${LATEST_IMAGE_TAG}"
