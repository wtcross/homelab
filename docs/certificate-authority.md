







### Lab wildcard cert

#### Create a config file to use the private key of the intermediate certificate to sign the CSR

Note: 

```
# sign_lab_wildcard_csr.ini

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
