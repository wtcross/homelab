#!/bin/bash
set -o nounset
set -o errexit

readonly GIT_TAG="v0.29.0"
readonly VERSION_IMAGE_TAG="ghcr.io/wtcross/step-ca:${GIT_TAG}"
readonly LATEST_IMAGE_TAG="ghcr.io/wtcross/step-ca:latest"

podman build \
    --build-arg TAG="${GIT_TAG}" \
    --tag "${VERSION_IMAGE_TAG}" \
    --tag "${LATEST_IMAGE_TAG}" \
    -f ubi10.hsm.Containerfile \
    .

podman push "${VERSION_IMAGE_TAG}"
podman push "${LATEST_IMAGE_TAG}"
