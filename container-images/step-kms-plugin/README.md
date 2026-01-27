# step-kms-plugin PKCS#11 Container Image

Minimal container image containing step-kms-plugin and step-cli for HSM key and certificate operations. Used for offline root CA operations and intermediate CA setup.

## Build

```bash
./build-and-push.sh
```

## Helper Scripts

Located in `scripts/` directory. These are external wrapper scripts that invoke the container via podman.

| Script | Description |
|--------|-------------|
| `create-key.sh` | Create a new ECDSA P-384 key on the HSM |
| `create-root-cert.sh` | Create a self-signed root CA certificate |
| `create-intermediate-csr.sh` | Create a CSR for an intermediate CA |
| `sign-intermediate.sh` | Sign an intermediate CSR with the root CA |

### Common Flags

All helper scripts accept these flags:

| Flag | Required | Description |
|------|----------|-------------|
| `--pkcs11-socket` | Yes | Path to PKCS#11 socket on host |
| `--pin-file` | Yes | Path to HSM PIN file on host |
| `--token` | Yes | Token/slot label on the HSM |
| `--key-id` | Yes | Key ID (hex, e.g., 01) |
| `--key-label` | Yes | Key object label |
| `--image` | No | Container image (default: ghcr.io/wtcross/step-kms-plugin:latest) |

## Example Usage

### Create Root CA Key

```bash
./scripts/create-key.sh \
    --pkcs11-socket /run/p11-kit/pkcs11 \
    --pin-file /path/to/hsm-pin \
    --token RootCA \
    --key-id 01 \
    --key-label root-key
```

### Create Root CA Certificate

```bash
./scripts/create-root-cert.sh \
    --pkcs11-socket /run/p11-kit/pkcs11 \
    --pin-file /path/to/hsm-pin \
    --token RootCA \
    --key-id 01 \
    --key-label root-key \
    --subject "My Root CA" \
    --output /path/to/root.crt
```

### Create Intermediate CA Key

```bash
./scripts/create-key.sh \
    --pkcs11-socket /run/p11-kit/pkcs11 \
    --pin-file /path/to/hsm-pin \
    --token IntermediateCA \
    --key-id 01 \
    --key-label intermediate-key
```

### Create Intermediate CA CSR

```bash
./scripts/create-intermediate-csr.sh \
    --pkcs11-socket /run/p11-kit/pkcs11 \
    --pin-file /path/to/hsm-pin \
    --token IntermediateCA \
    --key-id 01 \
    --key-label intermediate-key \
    --subject "My Intermediate CA" \
    --output /path/to/intermediate.csr
```

### Sign Intermediate Certificate

```bash
./scripts/sign-intermediate.sh \
    --pkcs11-socket /run/p11-kit/pkcs11 \
    --pin-file /path/to/hsm-pin \
    --token RootCA \
    --key-id 01 \
    --key-label root-key \
    --csr /path/to/intermediate.csr \
    --root-cert /path/to/root.crt \
    --output /path/to/intermediate.crt
```

## Direct Container Usage

You can also run step-kms-plugin and step commands directly:

```bash
# List keys on HSM
podman run --rm \
    -v /run/p11-kit/pkcs11:/run/pkcs11-socket:ro \
    ghcr.io/wtcross/step-kms-plugin:latest \
    step-kms-plugin key list --kms "pkcs11:module-path=/usr/lib64/p11-kit-proxy.so"

# Get certificate fingerprint
podman run --rm \
    -v ./cert.crt:/tmp/cert.crt:ro \
    ghcr.io/wtcross/step-kms-plugin:latest \
    step certificate fingerprint /tmp/cert.crt
```

## Volume Mounts (Direct Usage)

When using the container directly (not via helper scripts), mount these paths:

| Container Path | Description |
|----------------|-------------|
| `/run/pkcs11-socket` | PKCS#11 p11-kit server socket |
| `/run/secrets/hsm-pin` | HSM user PIN file (for PKCS#11 URI) |

## PKCS#11 URI Format (Direct Usage)

When using the container directly, construct URIs as follows:

**Token URI:**
```
pkcs11:module-path=/usr/lib64/p11-kit-proxy.so
```

**Private Key URI** (must include `pin-source`):
```
pkcs11:token=RootCA;id=%01;object=root-key?pin-source=/run/secrets/hsm-pin
```
