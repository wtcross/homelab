# Ansible Collection - wtcross.step

Ansible collection for deploying [step-ca](https://smallstep.com/docs/step-ca/) with PKCS#11/HSM support on RHEL.

> [!WARNING]
> Do not use this collection in production. It is for lab purposes only and no support is offered.

## Overview

Securely deploy `step-ca` in a rootless container on a RHEL 10 host. Below is a general summary of steps taken to secure this deployment:

- Use a streamlined container image built on `ubi10/ubi-minimal`
- Run the `step-ca` container as a user-scoped, rootless systemd quadlet
- Use a regular user (not system, shell set to `/sbin/nologin`) for running the quadlet
- Use a udev rule to allow the user to use a specific HSM, identified by vendor, product and serial
- Use a polkit rule to allow the user to access the HSM via pcscd
- Use `p11-kit server` to run a user-owned socket that can be mounted to the `step-ca` container
- The `step-ca` container runs with a custom SELinux policy that allows use of the user-owned pkcs#11 socket
- The `step-ca` container and pkcs#11 socket both use the same, static MCS (Multi-Category Security) level
- Enable firewalld and allow https traffic to the port configured for `step-ca`

## Requirements

- Container host must be on `RHEL 10.1` or later
- User configured as `ansible_user` must have the ability to become `root`

## Collection Dependencies

This collection requires:
- `ansible.posix` >= 1.0.0
- `containers.podman` >= 1.0.0

Install dependencies:
```bash
ansible-galaxy collection install ansible.posix containers.podman
```

## Roles

This collection provides three roles that should be used together:

| Role | Description |
| --- | --- |
| [step_host](roles/step_host/README.md) | Prepares the host OS with required packages |
| [step_user](roles/step_user/README.md) | Creates dedicated user and configures HSM access |
| [step_ca](roles/step_ca/README.md) | Deploys step-ca via Podman Quadlet with PKCS#11/HSM support |

## Quick Start

```yaml
- hosts: ca_servers
  vars:
    step_name: "My CA"
    step_dns_name: "ca.example.com"
    step_hsm_pkcs11_uri: "pkcs11:token=MyHSM"
    step_hsm_serial: "ABC123"
    step_hsm_vendor_id: "1050"
    step_hsm_product_id: "0407"
  roles:
    - wtcross.step.step_host
    - wtcross.step.step_user
    - wtcross.step.step_ca
```

## Installation

Install from Galaxy:
```bash
ansible-galaxy collection install wtcross.step
```

Or install from source:
```bash
ansible-galaxy collection build step-ansible/
ansible-galaxy collection install ./wtcross-step-*.tar.gz
```

## License

MIT-0
