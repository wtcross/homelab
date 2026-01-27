#!/bin/bash
# Add an X.509 certificate template to a provisioner
# Usage: add-x509-template.sh --ca-url URL --root CERT --admin-password-file FILE --provisioner NAME --template-file FILE [OPTIONS]
set -eo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Add an X.509 certificate template to an existing provisioner.

Required:
    --ca-url URL                 CA URL (e.g., https://ca.example.com)
    --root FILE                  Path to root CA certificate
    --admin-password-file FILE   Path to admin provisioner password file
    --provisioner NAME           Name of the provisioner to update
    --template-file FILE         Path to the X.509 template file (JSON/Go template)

Optional:
    --admin-provisioner NAME     Admin provisioner name (default: admin)
    --image IMAGE                Container image (default: ghcr.io/wtcross/step-cli:latest)
    --template-data FILE         Path to template data file (JSON)
    --help                       Show this help message

Example:
    $(basename "$0") \\
        --ca-url https://ca.example.com \\
        --root /path/to/root.crt \\
        --admin-password-file /path/to/admin-password \\
        --provisioner myprovisioner \\
        --template-file /path/to/x509-template.tpl
EOF
    exit 1
}

# Defaults
ADMIN_PROVISIONER="admin"
IMAGE="ghcr.io/wtcross/step-cli:latest"
TEMPLATE_DATA=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ca-url) CA_URL="$2"; shift 2 ;;
        --root) ROOT_CERT="$2"; shift 2 ;;
        --admin-password-file) ADMIN_PASSWORD_FILE="$2"; shift 2 ;;
        --admin-provisioner) ADMIN_PROVISIONER="$2"; shift 2 ;;
        --provisioner) PROVISIONER_NAME="$2"; shift 2 ;;
        --template-file) TEMPLATE_FILE="$2"; shift 2 ;;
        --template-data) TEMPLATE_DATA="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# Validate required arguments
[[ -z "${CA_URL:-}" ]] && { echo "Error: --ca-url is required" >&2; usage; }
[[ -z "${ROOT_CERT:-}" ]] && { echo "Error: --root is required" >&2; usage; }
[[ -z "${ADMIN_PASSWORD_FILE:-}" ]] && { echo "Error: --admin-password-file is required" >&2; usage; }
[[ -z "${PROVISIONER_NAME:-}" ]] && { echo "Error: --provisioner is required" >&2; usage; }
[[ -z "${TEMPLATE_FILE:-}" ]] && { echo "Error: --template-file is required" >&2; usage; }

# Validate files exist
[[ ! -f "${ROOT_CERT}" ]] && { echo "Error: Root cert not found: ${ROOT_CERT}" >&2; exit 1; }
[[ ! -f "${ADMIN_PASSWORD_FILE}" ]] && { echo "Error: Admin password file not found: ${ADMIN_PASSWORD_FILE}" >&2; exit 1; }
[[ ! -f "${TEMPLATE_FILE}" ]] && { echo "Error: Template file not found: ${TEMPLATE_FILE}" >&2; exit 1; }

# Build volume mounts
VOLUMES=(
    "-v" "$(realpath "${ROOT_CERT}"):/tmp/root.crt:ro"
    "-v" "$(realpath "${ADMIN_PASSWORD_FILE}"):/tmp/admin-password:ro"
    "-v" "$(realpath "${TEMPLATE_FILE}"):/tmp/x509-template.tpl:ro"
)

# Build step command
STEP_ARGS=(
    "ca" "provisioner" "update" "${PROVISIONER_NAME}"
    "--ca-url" "${CA_URL}"
    "--root" "/tmp/root.crt"
    "--admin-provisioner" "${ADMIN_PROVISIONER}"
    "--admin-password-file" "/tmp/admin-password"
    "--x509-template" "/tmp/x509-template.tpl"
)

# Add optional template data
if [[ -n "${TEMPLATE_DATA}" ]]; then
    [[ ! -f "${TEMPLATE_DATA}" ]] && { echo "Error: Template data file not found: ${TEMPLATE_DATA}" >&2; exit 1; }
    VOLUMES+=("-v" "$(realpath "${TEMPLATE_DATA}"):/tmp/template-data.json:ro")
    STEP_ARGS+=("--x509-template-data" "/tmp/template-data.json")
fi

exec podman run --rm "${VOLUMES[@]}" "${IMAGE}" step "${STEP_ARGS[@]}"
