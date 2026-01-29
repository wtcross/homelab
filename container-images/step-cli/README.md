# step-cli Container Image

Minimal container image containing step-cli for CA administration tasks. Includes helper scripts for common provisioner and policy management operations.

## Disclaimer

This image is **not distributed or signed by Smallstep**. However, the build process uses [cosign](https://github.com/sigstore/cosign) to verify the integrity of the source code tarball before compiling the binary included in this image.

If you prefer not to trust a third-party container image, you can use the Containerfile in this directory to build your own.

## Build

```bash
./build-and-push.sh
```

## Helper Scripts

Located in `scripts/` directory. These are wrapper scripts that invoke the step-cli container via podman.

| Script | Description |
|--------|-------------|
| `create-jwk-provisioner.sh` | Create a JWK provisioner with password |
| `create-oidc-provisioner.sh` | Create an OAuth/OIDC SSO provisioner |
| `create-sshpop-provisioner.sh` | Create an SSHPOP provisioner |
| `create-acme-provisioner.sh` | Create an ACME provisioner |
| `add-x509-template.sh` | Add X.509 certificate template to a provisioner |
| `add-ssh-template.sh` | Add SSH certificate template to a provisioner |
| `add-policy.sh` | Add certificate issuance policy rules |

### Common Flags

All helper scripts accept these flags:

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--ca-url` | Yes | - | CA URL (e.g., https://ca.example.com) |
| `--root` | Yes | - | Path to root CA certificate |
| `--admin-password-file` | Yes | - | Path to admin provisioner password file |
| `--admin-provisioner` | No | `admin` | Admin provisioner name |
| `--image` | No | `ghcr.io/wtcross/step-cli:latest` | Container image to use |

## Example Usage

### Create JWK Provisioner

```bash
./scripts/create-jwk-provisioner.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --name myprovisioner \
    --password-file /path/to/provisioner-password
```

### Create OIDC Provisioner (Google)

```bash
./scripts/create-oidc-provisioner.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --name google \
    --client-id "myapp.apps.googleusercontent.com" \
    --configuration-endpoint "https://accounts.google.com/.well-known/openid-configuration" \
    --domain example.com
```

### Create ACME Provisioner

```bash
./scripts/create-acme-provisioner.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --name acme
```

### Create ACME Provisioner with External Account Binding

```bash
./scripts/create-acme-provisioner.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --name acme-eab \
    --require-eab
```

### Create SSHPOP Provisioner

```bash
./scripts/create-sshpop-provisioner.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --name sshpop
```

### Add X.509 Template

```bash
./scripts/add-x509-template.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --provisioner myprovisioner \
    --template-file /path/to/x509-template.tpl
```

### Add SSH Template

```bash
./scripts/add-ssh-template.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    --provisioner myprovisioner \
    --template-file /path/to/ssh-template.tpl
```

### Add Certificate Issuance Policy

```bash
# Allow X.509 certificates for *.example.com
./scripts/add-policy.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    x509 allow dns "*.example.com" "example.com"

# Deny X.509 certificates for private IPs
./scripts/add-policy.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    x509 deny ip "10.0.0.0/8" "192.168.0.0/16"

# Allow SSH host certificates for specific domains
./scripts/add-policy.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    ssh-host allow dns "*.example.com"

# Allow SSH user certificates for specific emails
./scripts/add-policy.sh \
    --ca-url https://ca.example.com \
    --root /path/to/root.crt \
    --admin-password-file /path/to/admin-password \
    ssh-user allow email "*@example.com"
```

## Direct Container Usage

Run step commands directly:

```bash
# Get certificate info
podman run --rm \
    -v ./cert.crt:/tmp/cert.crt:ro \
    ghcr.io/wtcross/step-cli:latest \
    step certificate inspect /tmp/cert.crt

# Bootstrap CA trust
podman run --rm \
    ghcr.io/wtcross/step-cli:latest \
    step ca bootstrap --ca-url https://ca.example.com --fingerprint <fingerprint>

# Request a certificate
podman run --rm \
    -v ./root.crt:/tmp/root.crt:ro \
    -v ./output:/output:Z \
    ghcr.io/wtcross/step-cli:latest \
    step ca certificate myhost.example.com /output/cert.crt /output/key.pem \
        --ca-url https://ca.example.com \
        --root /tmp/root.crt \
        --provisioner acme
```
