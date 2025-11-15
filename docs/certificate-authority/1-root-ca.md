### Root CA

#### Create the root CA directory structure.

```
pki_dir=<path-to-certificate-authority-dir>
mkdir $pki_dir
cd $pki_dir
mkdir certs config crl newcerts intermediate intermediate/certs intermediate/crl intermediate/csr intermediate/newcerts
touch index.txt intermediate/index.txt
cd config
```

#### Create the root CA

```
pkcs11-tool --login --keypairgen \
  --key-type EC:secp384r1 \
  --label root
```

#### Create a config file to generate a self-signed public certificate

Fill out the request information in <angle brackets> with information for your CA:
```
# create_root_cert.ini
[ ca ]
default_ca = CA_default

[ CA_default ]
dir           = <path-to-certificate-authority-dir>
certs         = $dir/certs
crl_dir       = $dir/crl
new_certs_dir = $dir/newcerts
database      = $dir/index.txt
serial        = $dir/serial
default_md    = sha512
name_opt      = ca_default
cert_opt      = ca_default
default_days  = 375
preserve      = no
policy        = policy_strict

[ policy_strict ]
countryName            = match
stateOrProvinceName    = match
organizationName       = match
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

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

[ req_distinguished_name ]
C  = <two lettter country>
ST = <full state name>
O  = <your company>
OU = <your company> Certificate Authority
CN = <your company> Root CA
```

#### Generate the self-signed public certificate from the private key

```
openssl req \
  -config create_root_cert.ini \
  -engine pkcs11 \
  -keyform engine \
  -key <root-private-key-id-from-hsm> \
  -new -x509 \
  -days 3650 \
  -sha512 \
  -extensions v3_ca \
  -out ../certs/root.crt
```

#### Verify that the root certificate was generated correctly

```
openssl x509 -noout -text -in ../certs/root.crt
```
