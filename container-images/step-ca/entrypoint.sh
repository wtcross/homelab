#!/bin/bash
set -eo pipefail

# Entrypoint script for step-ca with PKCS#11 support
# Uses step ca init to bootstrap admin, then configures PKCS#11 key

STEPPATH="${STEPPATH:-/home/step/.step}"
CONFIG_FILE="${STEPPATH}/config/ca.json"

# Required environment variables
: "${STEP_CA_NAME:?STEP_CA_NAME is required}"
: "${STEP_CA_DNS_NAMES:?STEP_CA_DNS_NAMES is required}"
: "${STEP_PKCS11_PRIVATE_KEY_URI:?STEP_PKCS11_PRIVATE_KEY_URI is required}"
: "${STEP_ADMIN_PASSWORD_FILE:?STEP_ADMIN_PASSWORD_FILE is required}"

# Validate admin password file exists
if [ ! -f "${STEP_ADMIN_PASSWORD_FILE}" ]; then
    echo "Error: Admin password file not found at ${STEP_ADMIN_PASSWORD_FILE}" >&2
    exit 1
fi

# Optional environment variables with defaults
STEP_CA_ADDRESS="${STEP_CA_ADDRESS:-:9000}"
STEP_INTERMEDIATE_CERT_FILE="${STEP_INTERMEDIATE_CERT_FILE:-/run/secrets/intermediate.crt}"
STEP_ROOT_CERT_FILE="${STEP_ROOT_CERT_FILE:-/run/secrets/root.crt}"
STEP_ADMIN_SUBJECT="${STEP_ADMIN_SUBJECT:-step}"
STEP_ADMIN_PROVISIONER_NAME="${STEP_ADMIN_PROVISIONER_NAME:-admin}"

# Validate certificate files exist
if [ ! -f "${STEP_INTERMEDIATE_CERT_FILE}" ]; then
    echo "Error: Intermediate certificate not found at ${STEP_INTERMEDIATE_CERT_FILE}" >&2
    exit 1
fi

if [ ! -f "${STEP_ROOT_CERT_FILE}" ]; then
    echo "Error: Root certificate not found at ${STEP_ROOT_CERT_FILE}" >&2
    exit 1
fi

# Initialize CA if config doesn't exist
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Initializing CA configuration..."

    # Create temporary directory for step ca init
    TEMP_STEPPATH=$(mktemp -d)
    export STEPPATH="${TEMP_STEPPATH}"

    # Run step ca init to create provisioner and super admin
    step ca init \
        --name="${STEP_CA_NAME}" \
        --dns="${STEP_CA_DNS_NAMES}" \
        --address="${STEP_CA_ADDRESS}" \
        --provisioner="${STEP_ADMIN_PROVISIONER_NAME}" \
        --password-file="${STEP_ADMIN_PASSWORD_FILE}" \
        --provisioner-password-file="${STEP_ADMIN_PASSWORD_FILE}" \
        --remote-management \
        --admin-subject="${STEP_ADMIN_SUBJECT}" \
        --deployment-type=standalone

    # Reset STEPPATH to actual location
    STEPPATH="${STEPPATH:-/home/step/.step}"
    export STEPPATH

    # Extract provisioners from generated config
    PROVISIONERS=$(jq '.authority.provisioners' "${TEMP_STEPPATH}/config/ca.json")

    # Parse DNS names into JSON array
    IFS=',' read -ra DNS_ARRAY <<< "${STEP_CA_DNS_NAMES}"
    DNS_JSON=$(printf '%s\n' "${DNS_ARRAY[@]}" | jq -R . | jq -s .)

    # Create PKCS#11 ca.json using provisioners from init
    mkdir -p "${STEPPATH}/config"
    cat > "${CONFIG_FILE}" <<EOF
{
    "root": "${STEP_ROOT_CERT_FILE}",
    "crt": "${STEP_INTERMEDIATE_CERT_FILE}",
    "key": "${STEP_PKCS11_PRIVATE_KEY_URI}",
    "kms": {
        "type": "pkcs11",
        "uri": "pkcs11:module-path=/usr/lib64/p11-kit-proxy.so"
    },
    "address": "${STEP_CA_ADDRESS}",
    "dnsNames": ${DNS_JSON},
    "logger": {
        "format": "text"
    },
    "db": {
        "type": "badgerv2",
        "dataSource": "${STEPPATH}/db"
    },
    "authority": {
        "enableAdmin": true,
        "provisioners": ${PROVISIONERS}
    },
    "tls": {
        "cipherSuites": [
            "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
            "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        ],
        "minVersion": 1.2,
        "maxVersion": 1.3,
        "renegotiation": false
    }
}
EOF

    # Copy database containing super admin
    cp -r "${TEMP_STEPPATH}/db" "${STEPPATH}/"

    # Clean up temporary directory
    rm -rf "${TEMP_STEPPATH}"

    echo "CA configuration initialized successfully"
    echo "Admin subject: ${STEP_ADMIN_SUBJECT}"
    echo "Admin provisioner: ${STEP_ADMIN_PROVISIONER_NAME}"
fi

exec "${@}"
