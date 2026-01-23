# `step-ca-rootless-pkcs11`

> [!WARNING]  
> Do not use role in production. It is for lab purposes only and no support is offered.

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

## Role Variables

| Variable Name | Required | Description | Default |
| --- | --- | --- | --- |
| step_name | yes | The name of the PKI (ex: Company Lab CA ) | |
| step_dns_name | yes | The DNS name or IP address of the CA (ex: ca.lab.company.com) | |
| step_hsm_pkcs11_uri | yes | PKCS#11 URI of the token you want to use | |
| step_hsm_serial | yes | Serial of the token you want to use (`ID_SERIAL_SHORT` udev environment variable) | |
| step_hsm_vendor_id | yes | The idVendor attribute of the HSM as seen by udev | |
| step_hsm_product_id | yes | The idProduct attribute of the HSM as seen by udev | |
| step_https_port | no | The port that the `step-ca` https server should listen on | 9000 |
| step_uid | no | The UID of the step user | 1001 |
| step_gid | no | The GID of the step group | 1001 |
| step_user | no | The name of the step user | step |
| step_group | no | The name of the step group | step |

## Future Work

- add functional testing role
  - gets root.crt from running container or somewhere else
  - use `step ca health` to check health of CA
- further cleanup of container images
  - obtain source code via package archive in order to use cosign for verification
  - separate "init" images from "runtime" images
    - runtime images should only have the necessary libraries (ex: p11-kit-client.so) and binaries (ex: step-ca compiled for pkcs#11 support)
    - init images are intended to be used as oneshot services or used by admins
  - sign images
- build in initialization of the CA using separate init containers
  - use the step-kms-plugin image to create private keys
- get rid of the podman network and use socket activation with no network
- clean up quadlet config
- enhance the role so it can manage multiple instances of `step-ca`
  - this will require making sure host-level config (ex: udev and polkit rules) don't have config or naming collisions
  - `step-user` can be the same
  - pkcs#11 uri and other ca-specific variables can't be the same for two instances
- turn this into a content collection
  - break up role into separate roles in the collection to support more than just usb HSMs
- logic for handling removal of `step-ca` instances created by this role

