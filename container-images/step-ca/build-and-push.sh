#!/bin/bash
set -o nounset
set -o errexit

readonly GIT_TAG="v0.29.0"
readonly IMAGE_TAG="ghcr.io/wtcross/step-ca:${GIT_TAG}"

podman build \
    --build-arg TAG="${GIT_TAG}" \
    --tag "${IMAGE_TAG}" \
    -f ubi10.hsm.Containerfile \
    .

podman push "${IMAGE_TAG}"
