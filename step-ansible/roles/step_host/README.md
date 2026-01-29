# step_host

Prepares the host OS with required packages for step-ca deployment.

## Requirements

- RHEL 10.1 or later
- User configured as `ansible_user` must have the ability to become `root`

## Role Variables

| Variable | Required | Description | Default |
| --- | --- | --- | --- |
| step_host_os_packages | no | List of packages to install | acl, firewalld, python3-firewall, pcsc-lite, opensc, p11-kit, p11-kit-server, gnutls-utils, udica |
| step_host_update_packages | no | Whether to run dnf update | true |
| step_host_reboot_if_required | no | Whether to reboot if needed | true |

## Example Playbook

```yaml
- hosts: ca_servers
  roles:
    - role: wtcross.step.step_host
      vars:
        step_host_update_packages: true
        step_host_reboot_if_required: true
```

## License

MIT-0
