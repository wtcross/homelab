### Lab Intermediate CA

#### Generate private key on HSM

```
pkcs11-tool --login --keypairgen \
  --key-type EC:secp384r1 \
  --label lab-intermediate
```

#### Create a config file to generate a self-signed public certificate

Fill out the request information in <angle brackets> with information for your CA:
```
# create_lab_intermediate_csr.ini
[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign

[ req ]
default_bits       = 4096
distinguished_name = req_distinguished_name
string_mask        = utf8only
prompt             = no
default_md         = sha512

[ req_distinguished_name ]
C  = <two lettter country>
ST = <full state name>
O  = <your company>
OU = <your company> Certificate Authority
CN = <your company> Lab Intermediate CA
```

#### Generate the certificate signing request for the lab-intermediate CA from the intermediate CA’s private key

```
openssl req \
  -config create_lab_intermediate_csr.ini \
  -engine pkcs11 \
  -keyform engine \
  -key <lab-intermediate-private-key-id-from-hsm> \
  -new \
  -sha512 \
  -out ../intermediate/lab/csr/lab_intermediate.csr
```

#### Verify that the CSR was created correctly

- Verify that your Subject is correct.
- Verify that your Public Key and Signature Algorithm are correct.

```
openssl req -text -noout -verify -in ../intermediate/lab/csr/lab_intermediate.csr
```

#### Identify fully qualified PKCS#11 URI for your intermediate private key and create signing config

```
# sign_lab_intermediate_csr.ini
[ ca ]
default_ca = CA_default

[ CA_default ]
dir           = <path-to-certificate-authority-dir>/intermediate
certs         = $dir/certs
crl_dir       = $dir/crl
new_certs_dir = $dir/newcerts
database      = $dir/index.txt
serial        = $dir/serial
certificate   = $certs/intermediate.crt
private_key   = <intermediate-private-key-pkcs-11-uri>
default_md    = sha512
name_opt      = ca_default
cert_opt      = ca_default
default_days  = 375
preserve      = no
policy        = policy_loose

[ policy_loose ]
countryName            = optional
stateOrProvinceName    = optional
localityName           = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

[ v3_intermediate_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true, pathlen:0
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
```

#### Sign the lab-intermediate certificate with the intermediate certificate

```
openssl ca \
  -config sign_lab_intermediate_csr.ini \
  -engine pkcs11 \
  -keyform engine \
  -extensions v3_intermediate_ca \
  -days 375 \
  -notext \
  -md sha512 \
  -create_serial \
  -in ../intermediate/lab/csr/lab_intermediate.csr \
  -out ../intermediate/lab/certs/lab_intermediate.crt
```

#### Verify that the lab-intermediate certificate was generated correctly

- Verify that the Issuer and Subject are different, and correct.
- Verify that the Key Usage matches the config file.
- Verify that the signature algorithm are correct above and below.

```
openssl x509 -noout -text -in ../intermediate/lab/certs/lab_intermediate.crt
```

#### Verify that the lab-intermediate certificate verifies against the intermediate certificate

```
openssl verify -CAfile ../intermediate/certs/intermediate.crt ../intermediate/lab/certs/lab_intermediate.crt
```

#### Create a certificate chain file

```
cat ../intermediate/certs/intermediate.crt ../certs/root.crt > ../intermediate/certs/chain.crt
```
