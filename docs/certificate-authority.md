# Certificate Authority

## Notes

### Links
- [Nitrokey docs on this topic](https://docs.nitrokey.com/nitrokeys/features/openpgp-card/certificate-authority)

### Commands

- *list keys on HSM*: `pkcs11-tool -O`

## Requirements

### CA Storage

External storage device using LUKS encryption.

### HSM

Nitrokey HSM2

### Packages

`sudo dnf install opensc gnutls gnutls-util openssl-pkcs11-sign-provider openssl-pkcs11 pkcs11-provider pkcs11-helper`

## Setup

### Root CA

#### Create the root CA directory structure.

```
pki_dir=</path/to/certificate-authority>
mkdir $pki_dir
cd $pki_dir
mkdir certs config crl newcerts intermediate intermediate/certs intermediate/crl intermediate/csr intermediate/newcerts
touch index.txt intermediate/index.txt
cd config
```

#### Create the root CA

```
pkcs11-tool -l --keypairgen --key-type EC:secp384r1 --label root
```

#### Create a config file to generate a self-signed public certificate

Fill out the request information in <angle brackets> with information for your CA:
```
# vim create_root_cert.ini

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = </path/to/certificate-authority>
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha512

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict

[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
prompt              = no

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha512

[ req_distinguished_name ]
C                   = <two lettter country>
ST                  = <full state name>
O                   = <your company>
OU                  = <your company> Certificate Authority
CN                  = <your company> Root CA

[ v3_ca ]
# Extensions for a typical CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
```

#### Generate the self-signed public certificate from the private key

```
openssl req -config create_root_cert.ini -engine pkcs11 -keyform engine -key <root-private-key-id-from-hsm> -new -x509 -days 3650 -sha512 -extensions v3_ca -out ../certs/root.crt
```

#### Verify that the root certificate was generated correctly

```
openssl x509 -noout -text -in ../certs/root.crt
```

### Intermediate CA

#### Generate private key on HSM

```
pkcs11-tool -l --keypairgen --key-type EC:secp384r1 --label intermediate
```

#### Create a config file to generate a self-signed public certificate

Fill out the request information in <angle brackets> with information for your CA:
```
# vim create_intermediate_csr.ini

[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
prompt              = no

# SHA-1 is deprecated, so use SHA-2 instead.
[ v3_ca ]
# Extensions for a typical CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
default_md          = sha512

[ req_distinguished_name ]
C                   = <two lettter country>
ST                  = <full state name>
O                   = <your company>
OU                  = <your company> Certificate Authority
CN                  = <your company> Intermediate CA
```

#### Generate the certificate signing request for the intermediate CA from the intermediate CA’s private key

```
openssl req -config create_intermediate_csr.ini -engine pkcs11 -keyform engine -key <intermediate-private-key-id-from-hsm> -new -sha512 -out ../intermediate/csr/intermediate.csr
```

#### Verify that the CSR was created correctly

- Verify that your Subject is correct.
- Verify that your Public Key and Signature Algorithm are correct.

```
openssl req -text -noout -verify -in ../intermediate/csr/intermediate.csr
```

#### Identify fully qualified PKCS#11 URI for your root private key

```
# sign_intermediate_csr.ini

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = </path/to/certificate-authority>
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial

# The root key and root certificate.
private_key       = <root-private-key-pkcs-11-uri>
certificate       = ../certs/root.crt

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha512

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the `ca` man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ v3_intermediate_ca ]
# Extensions for a typical intermediate CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
```

#### Sign the intermediate certificate with the root certificate

```
openssl ca -config sign_intermediate_csr.ini -engine pkcs11 -keyform engine -extensions v3_intermediate_ca -days 1825 -notext -md sha512 -create_serial -in ../intermediate/csr/intermediate.csr -out ../intermediate/certs/intermediate.crt
```

#### Verify that the root certificate was generated correctly

- Verify that the Issuer and Subject are different, and correct.
- Verify that the Key Usage matches the config file.
- Verify that the signature algorithm are correct above and below.

```
openssl x509 -noout -text -in ../intermediate/certs/intermediate.crt
```

#### Verify that the intermediate certificate verifies against the root certificate

```
openssl verify -CAfile ../certs/root.crt ../intermediate/certs/intermediate.crt
```

#### Create a certificate chain file

```
cat ../intermediate/certs/intermediate.crt ../certs/root.crt > ../intermediate/certs/chain.crt
```

### Lab wildcard cert

#### Create a config file to use the private key of the intermediate certificate to sign the CSR

```
# sign_lab_wildcard_csr.ini

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = /opt/certificate-authority/intermediate
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial

# The root key and root certificate.
private_key       = <intermediate-private-key-pkcs-11-uri>
certificate       = $dir/certs/intermediate.crt

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha512

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the `ca` man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
prompt              = no
default_bits        = 4096
default_days        = 375
default_md          = sha512
string_mask         = utf8only
distinguished_name  = req_distinguished_name
req_extensions      = v3_req

[ crl_ext ]
# Extension for CRLs (man x509v3_config).
authorityKeyIdentifier = keyid:always

[ req_distinguished_name ]
C = AA
ST = Frogstar
L = City
O = AA Server
#OU = Certification Unit
CN = $CN
emailAddress = info@$CN
```
