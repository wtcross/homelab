#!/bin/bash
set -eo pipefail

export STEPPATH=$(step path)

# List of env vars required for step ca init
declare -ra REQUIRED_INIT_VARS=(STEPCA_INIT_NAME STEPCA_INIT_DNS_NAMES)

# Ensure all env vars required to run step ca init are set.
function init_if_possible () {
    local missing_vars=0
    for var in "${REQUIRED_INIT_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars=1
        fi
    done
    if [ ${missing_vars} = 1 ]; then
        >&2 echo "there is no ca.json config file; please run step ca init, or provide config parameters via STEPCA_INIT_ vars"
    else
        step_ca_init "${@}"
    fi
}

function generate_password () {
    set +o pipefail
    < /dev/urandom tr -dc A-Za-z0-9 | head -c40
    echo
    set -o pipefail
}

# Initialize a CA if not already initialized
function step_ca_init () {
    STEPCA_INIT_PROVISIONER_NAME="${STEPCA_INIT_PROVISIONER_NAME:-admin}"
    STEPCA_INIT_ADMIN_SUBJECT="${STEPCA_INIT_ADMIN_SUBJECT:-step}"
    STEPCA_INIT_ADDRESS="${STEPCA_INIT_ADDRESS:-:9000}"
    STEPCA_INIT_ROOT_FILE="${STEPCA_INIT_ROOT_FILE:-"/run/secrets/root_ca.crt"}"
    STEPCA_INIT_KEY_FILE="${STEPCA_INIT_KEY_FILE:-"/run/secrets/root_ca_key"}"
    STEPCA_INIT_KEY_PASSWORD_FILE="${STEPCA_INIT_KEY_PASSWORD_FILE:-"/run/secrets/root_ca_key_password"}"

    local -a setup_args=(
        --name "${STEPCA_INIT_NAME}"
        --dns "${STEPCA_INIT_DNS_NAMES}"
        --provisioner "${STEPCA_INIT_PROVISIONER_NAME}"
        --password-file "${STEPPATH}/password"
        --provisioner-password-file "${STEPPATH}/provisioner_password"
        --address "${STEPCA_INIT_ADDRESS}"
    )
    if [ -n "${STEPCA_INIT_PASSWORD_FILE}" ]; then
        cat < "${STEPCA_INIT_PASSWORD_FILE}" > "${STEPPATH}/password"
        cat < "${STEPCA_INIT_PASSWORD_FILE}" > "${STEPPATH}/provisioner_password"
    elif [ -n "${STEPCA_INIT_PASSWORD}" ]; then
        echo "${STEPCA_INIT_PASSWORD}" > "${STEPPATH}/password"
        echo "${STEPCA_INIT_PASSWORD}" > "${STEPPATH}/provisioner_password"
    else
        echo "${STEPPATH}/password"
        generate_password > "${STEPPATH}/password"
        generate_password > "${STEPPATH}/provisioner_password"
    fi
    if [ -f "${STEPCA_INIT_ROOT_FILE}" ]; then
        setup_args=("${setup_args[@]}" --root "${STEPCA_INIT_ROOT_FILE}")
    fi
    if [ -f "${STEPCA_INIT_KEY_FILE}" ]; then
        setup_args=("${setup_args[@]}" --key "${STEPCA_INIT_KEY_FILE}")
    fi
    if [ -f "${STEPCA_INIT_KEY_PASSWORD_FILE}" ]; then
        setup_args=("${setup_args[@]}" --key-password-file "${STEPCA_INIT_KEY_PASSWORD_FILE}")
    fi
    if [ -n "${STEPCA_INIT_DEPLOYMENT_TYPE}" ]; then
        setup_args=("${setup_args[@]}" --deployment-type "${STEPCA_INIT_DEPLOYMENT_TYPE}")
    fi
    if [ -n "${STEPCA_INIT_WITH_CA_URL}" ]; then
        setup_args=("${setup_args[@]}" --with-ca-url "${STEPCA_INIT_WITH_CA_URL}")
    fi
    if [ "${STEPCA_INIT_SSH}" == "true" ]; then
        setup_args=("${setup_args[@]}" --ssh)
    fi
    if [ "${STEPCA_INIT_ACME}" == "true" ]; then
        setup_args=("${setup_args[@]}" --acme)
    fi
    if [ "${STEPCA_INIT_REMOTE_MANAGEMENT}" == "true" ]; then
        setup_args=("${setup_args[@]}" --remote-management
                       --admin-subject "${STEPCA_INIT_ADMIN_SUBJECT}"
        )
    fi
    step ca init "${setup_args[@]}"
    echo ""
    if [ "${STEPCA_INIT_REMOTE_MANAGEMENT}" == "true" ]; then
        echo "Your CA administrative username is: ${STEPCA_INIT_ADMIN_SUBJECT}"
    fi
    echo "Your CA administrative password is: $(< $STEPPATH/provisioner_password )"
    echo "This will only be displayed once."
    shred -u $STEPPATH/provisioner_password
    mv $STEPPATH/password $PWDPATH
}

# if [ -f /usr/sbin/pcscd ]; then
#     /usr/sbin/pcscd
# fi

if [ ! -f "${STEPPATH}/config/ca.json" ]; then
    init_if_possible
fi

exec "${@}"
