# step_ca

Deploys step-ca via Podman Quadlet with PKCS#11/HSM support.

## Container Image Disclaimer

This role uses a custom container image that is **not distributed or signed by Smallstep**. The official `step-ca` container image is built without CGO, which means it lacks PKCS#11 support. Smallstep previously provided a CGO-enabled image but has since discontinued it. To enable HSM integration, this role uses a custom image compiled with `CGO_ENABLED=1`.

For more information on PKCS#11 requirements, see the [Smallstep documentation on cryptographic protection](https://smallstep.com/docs/step-ca/cryptographic-protection/#pkcs-11).

If you prefer not to trust a third-party container image, you can build your own using the Containerfiles in this project's `container-images/step-ca/` directory.

## Requirements

- RHEL 10.1 or later
- Requires `wtcross.step.step_user` to be run first
- User configured as `ansible_user` must have the ability to become `root`

## Role Variables

| Variable | Required | Description | Default |
| --- | --- | --- | --- |
| step_name | yes | The name of the PKI | |
| step_dns_name | yes | DNS name or IP of the CA | |
| step_hsm_pkcs11_uri | yes | PKCS#11 URI of the token | |
| step_https_port | no | HTTPS port for step-ca | 9000 |
| step_instance | no | Instance identifier | (derived from step_name) |
| step_user | no | Name of the step user | step |
| step_group | no | Name of the step group | step |
| step_uid | no | UID of the step user | 1001 |
| step_gid | no | GID of the step group | 1001 |

## Systemd Architecture

This role uses systemd extensively to manage the CA lifecycle. All services run as user-scoped units under a dedicated non-root user, leveraging systemd's support for user sessions via `loginctl enable-linger`.

### Unit Structure

```
~/.config/
├── containers/systemd/                    # Podman Quadlet units
│   ├── step-ca@.container                 # Instance template for CA container
│   ├── step-ca@.volume                    # Instance template for persistent data
│   ├── step-ca.network                    # Shared Podman network
│   └── step-ca@{instance}.container.d/    # Per-instance drop-in directory
│       └── 10-ports.conf                  # Port configuration
├── systemd/user/
│   ├── step-ca@.target                    # Instance template target
│   ├── p11-kit-server.target              # PKCS#11 server target
│   ├── p11-kit-server.service             # PKCS#11 server service
│   └── p11-kit-server.socket              # PKCS#11 socket activation
├── step-ca/
│   └── {instance}.env                     # CA-specific environment (name, DNS)
└── p11-kit-server/
    └── hsm.env                            # HSM PKCS#11 URI
```

### Instance Templates

The role uses systemd instance templates (units with `@` in their name) to support multiple CA deployments. The instance name becomes part of the unit name and is available as `%i` within the unit files.

For example, with `step_instance: root`:
- Target: `step-ca@root.target`
- Service: `step-ca@root.service`
- Volume: `step-ca-root-data`
- Container: `step-ca-root`
- Secret: `hsm-pin-root`

### Drop-in Configuration

Rather than templating the entire unit file, instance-specific configuration is applied via drop-in directories. This separation allows the base unit files to remain static and distributable independently (e.g., via RPM package), while Ansible only manages the minimal per-instance configuration.

The port drop-in (`10-ports.conf`) adds:
```ini
[Container]
PublishPort=9000:9000
```

### Environment Files

CA-specific settings that would otherwise require templating are provided via environment files:

**`~/.config/step-ca/{instance}.env`**:
```bash
STEPCA_INIT_NAME=My Root CA
STEPCA_INIT_DNS_NAMES=ca.example.com
```

**`~/.config/p11-kit-server/hsm.env`**:
```bash
STEP_HSM_PKCS11_URI=pkcs11:token=MyHSM;object=ca-key
```

### Service Dependencies

```
step-ca@{instance}.target
├── step-ca@{instance}.service (container)
│   └── Requires: p11-kit-server.target
├── step-ca-network.service
└── p11-kit-server.target
    ├── p11-kit-server.service
    └── p11-kit-server.socket
```

The CA container depends on `p11-kit-server.target` to ensure the PKCS#11 socket is available before the container starts.

## PKCS#11

This role enables the `step-ca` container to use a hardware security module (HSM) for cryptographic operations via PKCS#11. Since the container runs rootless and cannot directly access USB devices, the role uses [p11-kit server](https://p11-glue.github.io/p11-glue/p11-kit/manual/remoting.html) to expose the HSM over a Unix socket.

### How It Works

1. **Host-side HSM access**: The dedicated user is granted access to the HSM via udev and polkit rules (configured by `step_user` role)
2. **p11-kit server**: Runs as a user-scoped systemd service, exposing the HSM token over a Unix socket at `$XDG_RUNTIME_DIR/p11-kit/pkcs11-socket`
3. **Socket mount**: The socket is bind-mounted into the container at `/run/pkcs11-socket`
4. **Container PKCS#11 client**: The `step-ca` process inside the container connects to the socket using the `P11_KIT_SERVER_ADDRESS` environment variable

```
┌─────────────────────────────────────────────────────────────────┐
│ Host                                                            │
│                                                                 │
│  ┌──────────┐    USB     ┌─────────────────────────────────┐   │
│  │   HSM    │◄──────────►│  pcscd (system service)         │   │
│  └──────────┘            └─────────────────────────────────┘   │
│                                       ▲                         │
│                                       │ PC/SC API               │
│                                       ▼                         │
│                          ┌─────────────────────────────────┐   │
│                          │  p11-kit server (user service)  │   │
│                          │  opensc-pkcs11.so provider      │   │
│                          └───────────────┬─────────────────┘   │
│                                          │                      │
│                                          ▼                      │
│                          ┌─────────────────────────────────┐   │
│                          │  Unix Socket                     │   │
│                          │  /run/user/{uid}/p11-kit/pkcs11  │   │
│                          └───────────────┬─────────────────┘   │
│                                          │ bind mount           │
│  ┌───────────────────────────────────────┼─────────────────┐   │
│  │ step-ca container                     ▼                 │   │
│  │                       ┌─────────────────────────────┐   │   │
│  │                       │  /run/pkcs11-socket         │   │   │
│  │                       └──────────────┬──────────────┘   │   │
│  │                                      │                  │   │
│  │                                      ▼                  │   │
│  │                       ┌─────────────────────────────┐   │   │
│  │                       │  step-ca process            │   │   │
│  │                       │  (PKCS#11 client)           │   │   │
│  │                       └─────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## SELinux Policy

On SELinux-enabled systems (default for RHEL), the container cannot access the p11-kit socket without a custom policy. The role installs `step_ca_policy.cil`, which grants the container process permission to:

- Connect to the `unconfined_t` Unix stream socket (the p11-kit server socket)
- Access `container_file_t` labeled files, including the mounted socket
- Bind to HTTP ports for the CA's HTTPS listener

The policy is installed using `semodule` and combined with base container templates from [udica](https://github.com/containers/udica). Both the p11-kit socket and the container are labeled with the same MCS level (`s0:c100,c200`) to satisfy SELinux's MCS constraints.

## Environment Configuration

The PKCS#11 URI for the HSM token is stored in an environment file rather than being embedded in the systemd unit:

**`~/.config/p11-kit-server/hsm.env`**:
```bash
STEP_HSM_PKCS11_URI=pkcs11:token=MyHSM;object=ca-key
```

This value is passed to `p11-kit server` via the `--provider` argument to specify which token to expose.

## Multiple CAs on a Single Host

This role supports deploying multiple step-ca instances on the same host. Each CA runs under its own dedicated Linux user with isolated resources.

### Isolation Model

Each CA deployment gets:
- **Dedicated user account**: Separate home directory, UID/GID, and systemd user session
- **Isolated Podman resources**: Per-instance volumes, secrets, and container names
- **Unique port binding**: Each CA listens on a different host port
- **Separate HSM access**: Each user can have distinct udev/polkit rules for HSM access

### Example: Two-Tier PKI

Deploy a root CA and an issuing CA on the same host:

```yaml
- hosts: ca_server
  roles:
    # Host preparation (run once)
    - role: wtcross.step.step_host

    # Root CA - offline, rarely used
    - role: wtcross.step.step_user
      vars:
        step_user: step-root
        step_group: step-root
        step_uid: 2001
        step_gid: 2001
        step_hsm_serial: "ROOT123"
        step_hsm_vendor_id: "1050"
        step_hsm_product_id: "0407"

    - role: wtcross.step.step_ca
      vars:
        step_user: step-root
        step_group: step-root
        step_uid: 2001
        step_gid: 2001
        step_instance: root
        step_name: "ACME Root CA"
        step_dns_name: "root-ca.acme.corp"
        step_https_port: 9000
        step_hsm_pkcs11_uri: "pkcs11:token=RootHSM"

    # Issuing CA - online, handles certificate requests
    - role: wtcross.step.step_user
      vars:
        step_user: step-issuing
        step_group: step-issuing
        step_uid: 2002
        step_gid: 2002
        step_hsm_serial: "ISSUE456"
        step_hsm_vendor_id: "1050"
        step_hsm_product_id: "0407"

    - role: wtcross.step.step_ca
      vars:
        step_user: step-issuing
        step_group: step-issuing
        step_uid: 2002
        step_gid: 2002
        step_instance: issuing
        step_name: "ACME Issuing CA"
        step_dns_name: "ca.acme.corp"
        step_https_port: 9001
        step_hsm_pkcs11_uri: "pkcs11:token=IssuingHSM"
```

### Managing Instances

Each CA instance is managed independently via its user's systemd session:

```bash
# Check status of root CA (as root, targeting the step-root user)
sudo -u step-root XDG_RUNTIME_DIR=/run/user/2001 systemctl --user status step-ca@root.target

# Restart issuing CA
sudo -u step-issuing XDG_RUNTIME_DIR=/run/user/2002 systemctl --user restart step-ca@issuing.target

# View logs
sudo -u step-root XDG_RUNTIME_DIR=/run/user/2001 journalctl --user -u step-ca@root.service -f
```

### Resource Naming

With instance templates, resources are automatically namespaced:

| Resource | Single Instance | Multi-Instance (root) | Multi-Instance (issuing) |
| --- | --- | --- | --- |
| Container | `step-ca-root` | `step-ca-root` | `step-ca-issuing` |
| Volume | `step-ca-root-data` | `step-ca-root-data` | `step-ca-issuing-data` |
| Secret | `hsm-pin-root` | `hsm-pin-root` | `hsm-pin-issuing` |
| Target | `step-ca@root.target` | `step-ca@root.target` | `step-ca@issuing.target` |
| Port | 9000 | 9000 | 9001 |

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

    - role: wtcross.step.step_ca
      vars:
        step_name: "My CA"
        step_dns_name: "ca.example.com"
        step_hsm_pkcs11_uri: "pkcs11:token=MyHSM"
        step_https_port: 9000
```

## License

MIT-0
