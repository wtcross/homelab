# step_user

Creates a dedicated user and configures HSM access for step-ca deployment.

## Requirements

- RHEL 10.1 or later
- Requires `wtcross.step.step_host` to be run first
- User configured as `ansible_user` must have the ability to become `root`

## Role Variables

| Variable | Required | Description | Default |
| --- | --- | --- | --- |
| step_user | no | Name of the step user | step |
| step_group | no | Name of the step group | step |
| step_uid | no | UID of the step user | 1001 |
| step_gid | no | GID of the step group | 1001 |
| step_hsm_serial | yes | Serial of the token (ID_SERIAL_SHORT) | |
| step_hsm_vendor_id | yes | idVendor attribute of the HSM | |
| step_hsm_product_id | yes | idProduct attribute of the HSM | |

## HSM Access

This role configures the host to allow the step user to access the HSM via PKCS#11.

### udev Rules

A udev rule is created at `/etc/udev/rules.d/99-step-hsm.rules` that:
- Matches the HSM by vendor ID, product ID, and serial number
- Grants the step group read/write access to the device
- Sets environment variables for smartcard reader identification

### polkit Rules

A polkit rule is created at `/etc/polkit-1/rules.d/50-step-pcsc.rules` that:
- Allows members of the step group to access pcscd
- Grants permission to interact with smartcards via the PC/SC API

## Example Playbook

```yaml
- hosts: ca_servers
  roles:
    - role: wtcross.step.step_host

    - role: wtcross.step.step_user
      vars:
        step_user: step
        step_uid: 1001
        step_gid: 1001
        step_hsm_serial: "ABC123"
        step_hsm_vendor_id: "1050"
        step_hsm_product_id: "0407"
```

## License

MIT-0
