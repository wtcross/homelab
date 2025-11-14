# Certificate Authority

## Notes

### Links
- [Nitrokey docs on this topic](https://docs.nitrokey.com/nitrokeys/features/openpgp-card/certificate-authority)

### Commands

- *list public keys on the HSM*: `pkcs11-tool -O`
- *list private keys on the HSM* `pkcs11-tool --login --pin <yourpinhere> --list-objects --type privkey`

## Requirements

### CA Storage

External storage device using LUKS encryption.

### HSM

Nitrokey HSM2

### Packages

`sudo dnf install opensc gnutls gnutls-util openssl-pkcs11-sign-provider openssl-pkcs11 pkcs11-provider pkcs11-helper`

## Setup

1. [Root CA](./1-root-ca.md)
2. [Intermediate CA](./2-intermediate-ca.md)
3. [Lab Intermediate CA](./3-lab-intermediate-ca.md)
