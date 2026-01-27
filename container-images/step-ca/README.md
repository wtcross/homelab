# step-ca PKCS#11 Container Image

Minimal container image for running step-ca as an intermediate CA with PKCS#11 support for HSM-based private key operations.

## Build

```bash
./build-and-push.sh
```

## Required Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `STEP_CA_NAME` | Yes | - | Name of the CA |
| `STEP_CA_DNS_NAMES` | Yes | - | Comma-separated DNS names for the CA |
| `STEP_PKCS11_PRIVATE_KEY_URI` | Yes | - | PKCS#11 URI for intermediate CA private key |
| `STEP_ADMIN_PASSWORD_FILE` | Yes | - | Path to admin provisioner password file |
| `STEP_CA_ADDRESS` | No | `:9000` | Listen address |
| `STEP_INTERMEDIATE_CERT_FILE` | No | `/run/secrets/intermediate.crt` | Intermediate certificate path |
| `STEP_ROOT_CERT_FILE` | No | `/run/secrets/root.crt` | Root certificate path |
| `STEP_ADMIN_SUBJECT` | No | `step` | Admin user subject name |
| `STEP_ADMIN_PROVISIONER_NAME` | No | `admin` | Admin provisioner name |

## Required Volume Mounts

| Container Path | Description |
|----------------|-------------|
| `/run/pkcs11-socket` | PKCS#11 p11-kit server socket |
| `/run/secrets/root.crt` | Root CA certificate |
| `/run/secrets/intermediate.crt` | Intermediate CA certificate |
| `/run/secrets/admin-password` | Admin provisioner password file |
| `/run/secrets/hsm-pin` | HSM user PIN file (for PKCS#11 URI) |
| `/home/step/.step` | Persistent data volume (database, config) |

## PKCS#11 URI Format

The `STEP_PKCS11_PRIVATE_KEY_URI` must include the path to the PIN file using `pin-source`:

```
pkcs11:token=IntermediateCA;id=%01;object=private-key?pin-source=/run/secrets/hsm-pin
```

**URI Components:**
- `token` - Token/slot label on the HSM
- `id` - Key ID (hex-encoded, e.g., `%01` for ID 1)
- `object` - Key object label
- `pin-source` - Path to file containing the HSM user PIN

## Example Usage

```bash
podman run -d \
    --name step-ca \
    -e STEP_CA_NAME="My Intermediate CA" \
    -e STEP_CA_DNS_NAMES="ca.example.com,localhost" \
    -e STEP_PKCS11_PRIVATE_KEY_URI="pkcs11:token=IntermediateCA;id=%01;object=private-key?pin-source=/run/secrets/hsm-pin" \
    -e STEP_ADMIN_PASSWORD_FILE="/run/secrets/admin-password" \
    -v /run/p11-kit/pkcs11:/run/pkcs11-socket:ro \
    -v ./root.crt:/run/secrets/root.crt:ro \
    -v ./intermediate.crt:/run/secrets/intermediate.crt:ro \
    -v ./admin-password:/run/secrets/admin-password:ro \
    -v ./hsm-pin:/run/secrets/hsm-pin:ro \
    -v step-ca-data:/home/step/.step \
    -p 9000:9000 \
    ghcr.io/wtcross/step-ca:latest
```

## Systemd Quadlet Example

```ini
[Container]
ContainerName=step-ca
Image=ghcr.io/wtcross/step-ca:latest
Environment=STEP_CA_NAME="My Intermediate CA"
Environment=STEP_CA_DNS_NAMES="ca.example.com"
Environment=STEP_PKCS11_PRIVATE_KEY_URI="pkcs11:token=IntermediateCA;id=%01;object=private-key?pin-source=/run/secrets/hsm-pin"
Environment=STEP_ADMIN_PASSWORD_FILE="/run/secrets/admin-password"
Volume=/run/p11-kit/pkcs11:/run/pkcs11-socket:ro
Volume=%h/step-ca/root.crt:/run/secrets/root.crt:ro
Volume=%h/step-ca/intermediate.crt:/run/secrets/intermediate.crt:ro
Volume=%h/step-ca/admin-password:/run/secrets/admin-password:ro
Volume=%h/step-ca/hsm-pin:/run/secrets/hsm-pin:ro
Volume=step-ca-data:/home/step/.step
PublishPort=9000:9000

[Service]
Restart=always

[Install]
WantedBy=default.target
```

## First Run

On first startup, the container will:
1. Run `step ca init` to bootstrap the admin provisioner and super admin user
2. Generate `ca.json` configured for PKCS#11 key operations
3. Start the CA server

The admin provisioner password is used to authenticate for CA administration tasks.
