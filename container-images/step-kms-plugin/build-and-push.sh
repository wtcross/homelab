#!/bin/bash
set -o nounset
set -o errexit

readonly GIT_TAG="v0.16.0"
readonly IMAGE_TAG="ghcr.io/wtcross/step-kms-plugin:${GIT_TAG}"

podman build \
    --build-arg TAG="${GIT_TAG}" \
    --tag "${IMAGE_TAG}" \
    -f ubi10.Containerfile \
    .

podman push "${IMAGE_TAG}"
