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
default_md          = sha512

[ v3_ca ]
# Extensions for a typical CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

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
