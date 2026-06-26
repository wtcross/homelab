# PKCS#11 Notes

### Initializing a PKCS11 HSM

```bash
pkcs11-tool --module /usr/lib64/pkcs11/opensc-pkcs11.so  --init-token --init-pin --label labelgoeshere --login
```

### Change SO-PIN

```bash
pkcs11-tool --module /usr/lib64/pkcs11/opensc-pkcs11.so --login --login-type so --change-pin
```

### Change User PIN

```bash
pkcs11-tool --module /usr/lib64/pkcs11/opensc-pkcs11.so --login --change-pin
```

### Generate a Private Key

```bash
pkcs11-tool --module /usr/lib64/pkcs11/opensc-pkcs11.so  --login --keypairgen --key-type EC:secp384r1 --label labelgoeshere
```