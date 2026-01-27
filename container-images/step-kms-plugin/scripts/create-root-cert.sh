#!/bin/bash
# Create a self-signed root CA certificate using a key on the HSM
# Usage: create-root-cert.sh --pkcs11-socket PATH --pin-file PATH --token NAME --key-id ID --key-label LABEL --subject SUBJECT --output FILE [OPTIONS]
set -eo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a self-signed root CA certificate using a key on the HSM.

Required:
    --pkcs11-socket PATH    Path to PKCS#11 socket on host
    --pin-file PATH         Path to HSM PIN file on host
    --token NAME            Token/slot label on the HSM
    --key-id ID             Key ID (hex, e.g., 01)
    --key-label LABEL       Key object label
    --subject SUBJECT       Certificate subject (e.g., "My Root CA")
    --output FILE           Output path for the certificate

Optional:
    --image IMAGE           Container image (default: ghcr.io/wtcross/step-kms-plugin:latest)
    --not-after DURATION    Certificate validity duration (default: 87600h = 10 years)
    --help                  Show this help message

Example:
    $(basename "$0") \\
        --pkcs11-socket /run/p11-kit/pkcs11 \\
        --pin-file /path/to/hsm-pin \\
        --token RootCA \\
        --key-id 01 \\
        --key-label root-key \\
        --subject "My Root CA" \\
        --output /path/to/root.crt
EOF
    exit 1
}

# Defaults
IMAGE="ghcr.io/wtcross/step-kms-plugin:latest"
NOT_AFTER="87600h"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pkcs11-socket) PKCS11_SOCKET="$2"; shift 2 ;;
        --pin-file) PIN_FILE="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --key-id) KEY_ID="$2"; shift 2 ;;
        --key-label) KEY_LABEL="$2"; shift 2 ;;
        --subject) SUBJECT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --not-after) NOT_AFTER="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# Validate required arguments
[[ -z "${PKCS11_SOCKET:-}" ]] && { echo "Error: --pkcs11-socket is required" >&2; usage; }
[[ -z "${PIN_FILE:-}" ]] && { echo "Error: --pin-file is required" >&2; usage; }
[[ -z "${TOKEN:-}" ]] && { echo "Error: --token is required" >&2; usage; }
[[ -z "${KEY_ID:-}" ]] && { echo "Error: --key-id is required" >&2; usage; }
[[ -z "${KEY_LABEL:-}" ]] && { echo "Error: --key-label is required" >&2; usage; }
[[ -z "${SUBJECT:-}" ]] && { echo "Error: --subject is required" >&2; usage; }
[[ -z "${OUTPUT:-}" ]] && { echo "Error: --output is required" >&2; usage; }

# Validate paths exist
[[ ! -e "${PKCS11_SOCKET}" ]] && { echo "Error: PKCS#11 socket not found: ${PKCS11_SOCKET}" >&2; exit 1; }
[[ ! -f "${PIN_FILE}" ]] && { echo "Error: PIN file not found: ${PIN_FILE}" >&2; exit 1; }

# Get output directory and filename
OUTPUT_DIR=$(dirname "$(realpath -m "${OUTPUT}")")
OUTPUT_FILE=$(basename "${OUTPUT}")

# Ensure output directory exists
[[ ! -d "${OUTPUT_DIR}" ]] && { echo "Error: Output directory does not exist: ${OUTPUT_DIR}" >&2; exit 1; }

# Build PKCS#11 URIs
TOKEN_URI="pkcs11:module-path=/usr/lib64/p11-kit-proxy.so"
KEY_URI="pkcs11:token=${TOKEN};id=%${KEY_ID};object=${KEY_LABEL}?pin-source=/run/secrets/hsm-pin"

# Build volume mounts
VOLUMES=(
    "-v" "$(realpath "${PKCS11_SOCKET}"):/run/pkcs11-socket:ro"
    "-v" "$(realpath "${PIN_FILE}"):/run/secrets/hsm-pin:ro"
    "-v" "${OUTPUT_DIR}:/output:Z"
)

exec podman run --rm "${VOLUMES[@]}" "${IMAGE}" \
    step certificate create --profile root-ca \
    --kms "${TOKEN_URI}" \
    --key "${KEY_URI}" \
    --not-after "${NOT_AFTER}" \
    "${SUBJECT}" "/output/${OUTPUT_FILE}"
