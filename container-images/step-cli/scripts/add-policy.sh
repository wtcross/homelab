#!/bin/bash
# Add certificate issuance policy to the CA authority
# Usage: add-policy.sh --ca-url URL --root CERT --admin-password-file FILE <policy-type> <action> <name-type> <names...>
set -eo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <policy-type> <action> <name-type> <names...>

Add certificate issuance policy rules to the CA authority.

Required options:
    --ca-url URL                 CA URL (e.g., https://ca.example.com)
    --root FILE                  Path to root CA certificate
    --admin-password-file FILE   Path to admin provisioner password file

Optional options:
    --admin-provisioner NAME     Admin provisioner name (default: admin)
    --image IMAGE                Container image (default: ghcr.io/wtcross/step-cli:latest)
    --help                       Show this help message

Positional arguments:
    policy-type                  x509 | ssh-host | ssh-user
    action                       allow | deny
    name-type                    For x509: dns, email, ip, uri, cn
                                 For ssh-host: dns, ip, principal
                                 For ssh-user: email, principal
    names                        One or more names/patterns to allow or deny

Examples:
    # Allow X.509 certificates for *.example.com
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        x509 allow dns "*.example.com" "example.com"

    # Deny X.509 certificates for specific IPs
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        x509 deny ip "10.0.0.0/8" "192.168.0.0/16"

    # Allow SSH host certificates for specific domains
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        ssh-host allow dns "*.example.com"

    # Allow SSH user certificates for specific emails
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        ssh-user allow email "*@example.com"
EOF
    exit 1
}

# Defaults
ADMIN_PROVISIONER="admin"
IMAGE="ghcr.io/wtcross/step-cli:latest"

# Parse options (stop at first non-option argument)
while [[ $# -gt 0 ]]; do
    case $1 in
        --ca-url) CA_URL="$2"; shift 2 ;;
        --root) ROOT_CERT="$2"; shift 2 ;;
        --admin-password-file) ADMIN_PASSWORD_FILE="$2"; shift 2 ;;
        --admin-provisioner) ADMIN_PROVISIONER="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) break ;;  # Start of positional arguments
    esac
done

# Validate required options
[[ -z "${CA_URL:-}" ]] && { echo "Error: --ca-url is required" >&2; usage; }
[[ -z "${ROOT_CERT:-}" ]] && { echo "Error: --root is required" >&2; usage; }
[[ -z "${ADMIN_PASSWORD_FILE:-}" ]] && { echo "Error: --admin-password-file is required" >&2; usage; }

# Parse positional arguments
[[ $# -lt 4 ]] && { echo "Error: Missing positional arguments" >&2; usage; }

POLICY_TYPE="$1"
ACTION="$2"
NAME_TYPE="$3"
shift 3
NAMES=("$@")

# Validate policy type
case "${POLICY_TYPE}" in
    x509|ssh-host|ssh-user) ;;
    *) echo "Error: Invalid policy-type: ${POLICY_TYPE}. Must be: x509, ssh-host, ssh-user" >&2; exit 1 ;;
esac

# Validate action
case "${ACTION}" in
    allow|deny) ;;
    *) echo "Error: Invalid action: ${ACTION}. Must be: allow, deny" >&2; exit 1 ;;
esac

# Validate name type based on policy type
case "${POLICY_TYPE}" in
    x509)
        case "${NAME_TYPE}" in
            dns|email|ip|uri|cn) ;;
            *) echo "Error: Invalid name-type for x509: ${NAME_TYPE}. Must be: dns, email, ip, uri, cn" >&2; exit 1 ;;
        esac
        ;;
    ssh-host)
        case "${NAME_TYPE}" in
            dns|ip|principal) ;;
            *) echo "Error: Invalid name-type for ssh-host: ${NAME_TYPE}. Must be: dns, ip, principal" >&2; exit 1 ;;
        esac
        ;;
    ssh-user)
        case "${NAME_TYPE}" in
            email|principal) ;;
            *) echo "Error: Invalid name-type for ssh-user: ${NAME_TYPE}. Must be: email, principal" >&2; exit 1 ;;
        esac
        ;;
esac

# Validate files exist
[[ ! -f "${ROOT_CERT}" ]] && { echo "Error: Root cert not found: ${ROOT_CERT}" >&2; exit 1; }
[[ ! -f "${ADMIN_PASSWORD_FILE}" ]] && { echo "Error: Admin password file not found: ${ADMIN_PASSWORD_FILE}" >&2; exit 1; }

# Build volume mounts
VOLUMES=(
    "-v" "$(realpath "${ROOT_CERT}"):/tmp/root.crt:ro"
    "-v" "$(realpath "${ADMIN_PASSWORD_FILE}"):/tmp/admin-password:ro"
)

# Build step command based on policy type
case "${POLICY_TYPE}" in
    x509)
        STEP_ARGS=(
            "ca" "policy" "authority" "x509" "${ACTION}" "${NAME_TYPE}" "add"
        )
        ;;
    ssh-host)
        STEP_ARGS=(
            "ca" "policy" "authority" "ssh" "host" "${ACTION}" "${NAME_TYPE}" "add"
        )
        ;;
    ssh-user)
        STEP_ARGS=(
            "ca" "policy" "authority" "ssh" "user" "${ACTION}" "${NAME_TYPE}" "add"
        )
        ;;
esac

# Add names
STEP_ARGS+=("${NAMES[@]}")

# Add common flags
STEP_ARGS+=(
    "--ca-url" "${CA_URL}"
    "--root" "/tmp/root.crt"
    "--admin-provisioner" "${ADMIN_PROVISIONER}"
    "--admin-password-file" "/tmp/admin-password"
)

exec podman run --rm "${VOLUMES[@]}" "${IMAGE}" step "${STEP_ARGS[@]}"
