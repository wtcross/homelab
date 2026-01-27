#!/bin/bash
# Create an ACME provisioner on a step-ca instance
# Usage: create-acme-provisioner.sh --ca-url URL --root CERT --admin-password-file FILE --name NAME [OPTIONS]
set -eo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create an ACME provisioner on a step-ca instance.
This provisioner enables automated certificate issuance via the ACME protocol.

Required:
    --ca-url URL                 CA URL (e.g., https://ca.example.com)
    --root FILE                  Path to root CA certificate
    --admin-password-file FILE   Path to admin provisioner password file
    --name NAME                  Name for the new provisioner

Optional:
    --admin-provisioner NAME     Admin provisioner name (default: admin)
    --image IMAGE                Container image (default: ghcr.io/wtcross/step-cli:latest)
    --require-eab                Require External Account Binding
    --challenge TYPE             Allowed challenge type: http-01, dns-01, tls-alpn-01 (can be repeated)
    --help                       Show this help message

Example:
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        --name acme

    # With External Account Binding required:
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        --name acme \\
        --require-eab
EOF
    exit 1
}

# Defaults
ADMIN_PROVISIONER="admin"
IMAGE="ghcr.io/wtcross/step-cli:latest"
REQUIRE_EAB=""
CHALLENGES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ca-url) CA_URL="$2"; shift 2 ;;
        --root) ROOT_CERT="$2"; shift 2 ;;
        --admin-password-file) ADMIN_PASSWORD_FILE="$2"; shift 2 ;;
        --admin-provisioner) ADMIN_PROVISIONER="$2"; shift 2 ;;
        --name) PROVISIONER_NAME="$2"; shift 2 ;;
        --require-eab) REQUIRE_EAB="true"; shift ;;
        --challenge) CHALLENGES+=("$2"); shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# Validate required arguments
[[ -z "${CA_URL:-}" ]] && { echo "Error: --ca-url is required" >&2; usage; }
[[ -z "${ROOT_CERT:-}" ]] && { echo "Error: --root is required" >&2; usage; }
[[ -z "${ADMIN_PASSWORD_FILE:-}" ]] && { echo "Error: --admin-password-file is required" >&2; usage; }
[[ -z "${PROVISIONER_NAME:-}" ]] && { echo "Error: --name is required" >&2; usage; }

# Validate files exist
[[ ! -f "${ROOT_CERT}" ]] && { echo "Error: Root cert not found: ${ROOT_CERT}" >&2; exit 1; }
[[ ! -f "${ADMIN_PASSWORD_FILE}" ]] && { echo "Error: Admin password file not found: ${ADMIN_PASSWORD_FILE}" >&2; exit 1; }

# Build volume mounts
VOLUMES=(
    "-v" "$(realpath "${ROOT_CERT}"):/tmp/root.crt:ro"
    "-v" "$(realpath "${ADMIN_PASSWORD_FILE}"):/tmp/admin-password:ro"
)

# Build step command
STEP_ARGS=(
    "ca" "provisioner" "add" "${PROVISIONER_NAME}"
    "--type" "ACME"
    "--ca-url" "${CA_URL}"
    "--root" "/tmp/root.crt"
    "--admin-provisioner" "${ADMIN_PROVISIONER}"
    "--admin-password-file" "/tmp/admin-password"
)

# Add optional arguments
[[ -n "${REQUIRE_EAB}" ]] && STEP_ARGS+=("--require-eab")

for challenge in "${CHALLENGES[@]}"; do
    STEP_ARGS+=("--challenge" "${challenge}")
done

exec podman run --rm "${VOLUMES[@]}" "${IMAGE}" step "${STEP_ARGS[@]}"
