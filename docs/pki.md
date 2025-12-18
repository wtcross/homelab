# Cross Solutions CA

```
pki_dir=/home/step/certificate-authority
mkdir $pki_dir && cd $pki_dir
mkdir certs config crl newcerts intermediate intermediate/certs intermediate/crl intermediate/csr intermediate/newcerts
touch index.txt intermediate/index.txt
cd config
```

## Deployment Guide

### 1. Initialize Nitrokey HSM2 (if not already initialized)

If the device is new, you must initialize it (set SO PIN and user PIN).

```bash
# Initialize HSM (this will prompt for new PINs)
pkcs11-tool --module /usr/lib64/pkcs11/opensc-pkcs11.so  --init-token --init-pin --label="RootCA" --login
```

### 2. Create Root CA private key

Generate a P-384 elliptic curve key pair on the Nitrokey HSM2. Use `pkcs11-tool` (part of OpenSC) with the `--keypairgen` option. We will label each key and give it an ID for reference. The label and ID are arbitrary but should be unique per key. For example:

```bash
# Generate Root CA key on HSM (EC P-384)
pkcs11-tool --module /usr/lib64/opensc-pkcs11.so --login --keypairgen --key-type EC:secp384r1 --id 01 --label "root"
```

These commands will prompt for the User PIN. After each, the HSM will hold a private key and public key object. We assigned hex IDs 01, 02, ... 06 for convenience; you can use any IDs (or labels) as long as they match what will be used in OpenSSL commands or config URIs.

**Verify keys:** You can list objects on the HSM to verify, e.g.:

```bash
pkcs11-tool --module /usr/lib64/opensc-pkcs11.so --login --list-slots --list-objects
```

This should show the keys (public and private) with their labels and IDs.

### 3. Create the Root CA Self-Signed Certificate

```bash
# Generate Root CA self-signed certificate (valid 3650 days)
openssl req -config create_root_cert.ini \
    -key "pkcs11:object=root;type=private;id=%01" -new -x509 -sha512 \
    -extensions v3_ca -out ../certs/root.crt
```

*Explanation:*

- `-new -x509` tells OpenSSL to create a self-signed cert instead of a CSR.
- `-engine pkcs11 -keyform engine` loads the pkcs11 engine and indicates the key is provided by an engine.
- `-key "pkcs11:object=Cross Solutions Root CA;type=private"` identifies our Root CA key on the HSM. (Adjust the object label if needed or use `id=<ID>` if you prefer e.g., `pkcs11:id=01;type=private` for id 0x01.)
- `-sha512 -days 3650` uses SHA-512 and sets validity to 10 years.
- `-config root-ca.conf -extensions root_ca_reqext` uses our config file and the `[root_ca_reqext]` section for the certificate extensions.
- `-out ./ca/root-ca/root-ca.crt` writes the PEM certificate. (Ensure the directories exist; e.g., create `./ca/root-ca/` and subfolders as needed. The index and serial files will also need to exist—OpenSSL `ca` will create some if missing, but you may have to create `db` directory and empty files `root-ca.db`, `root-ca.crt.srl` (with a serial number) etc. The PKI tutorial suggests populating an initial serial file with “01” or using `rand_serial = yes` as we did, which will auto-generate a random serial.)

After running this, you should have `root-ca.crt` which is the self-signed root certificate. Inspect it:

```bash
openssl x509 -noout -text -in ./ca/root-ca/root-ca.crt
```

Verify that it has `CA:TRUE` basic constraints, pathlen:2, etc., and the issuer and subject are “Cross Solutions Root CA”. The SKI and AKI (should be the same since self-signed). No EKU (we didn’t set one for root), and no AIA (as expected). If anything is missing or incorrect, adjust the config and regenerate (you’d need to delete the old certificate and possibly reset the serial file).

**Initialize Root CA database:** Before proceeding to sign subordinates, prepare the root CA’s index and serial files:

```bash
touch ./ca/root-ca/db/root-ca.db             # index database
echo 1000 > ./ca/root-ca/db/root-ca.crt.srl  # initial serial (hex or decimal). Since we set rand_serial=yes, OpenSSL will override with random serials.
echo 1000 > ./ca/root-ca/db/root-ca.crl.srl  # CRL number file (start at 1000 or 1)
```

*(The above ensures the index and CRL number files exist. We set “1000” as a placeholder—actually with `rand_serial=yes`, when we issue certs, random serials will be used and the .srl will be updated to a random value.)*

### 4. Issue Certificates for Tier-2 CAs (Email, Software, VPN, Lab TLS)

For each Tier-2 CA, we will create a Certificate Signing Request (CSR) using its HSM key, then use the Root CA to sign it, producing the subordinate CA certificate.

**A. Generate CSR for Email CA:**

```bash
openssl req -new -engine pkcs11 -keyform engine \
    -key "pkcs11:object=Cross Solutions Email CA;type=private" \
    -sha512 -config email-ca.conf -extensions ca_reqext \
    -out ./ca/email-ca/email-ca.csr
```

This uses the email CA’s key on the HSM and the `email-ca.conf` config. The `-extensions ca_reqext` ensures the CSR includes the desired extensions (keyUsage, basicConstraints, etc.) for informational purposes. (OpenSSL will include them as CSR attributes, but note that by default our root will not copy these from the CSR; we will apply our own verified extension profile when signing.)

Check the CSR if desired:

```bash
openssl req -noout -text -in ./ca/email-ca/email-ca.csr
```

It should show CA:TRUE, pathlen:0 in the request extensions and CN “Cross Solutions Email CA” as subject.

**B. Sign the Email CA CSR with the Root CA:**

```bash
openssl ca -engine pkcs11 -keyform engine \
    -config root-ca.conf -extensions email_ca_ext \
    -in ./ca/email-ca/email-ca.csr \
    -out ./ca/email-ca/email-ca.crt
```

**Explanation:** We invoke the `openssl ca` utility, which will use the `[root_ca]` section for the root CA. The `-engine pkcs11 -keyform engine` ensures OpenSSL can access the root’s key from the HSM (as configured in root-ca.conf’s `private_key` using a PKCS#11 URI). We specify `-extensions email_ca_ext` to use the profile we defined for Email CA in the root config
pki-tutorial.readthedocs.io
. OpenSSL will load the root CA’s private key via the engine and sign the CSR, producing `email-ca.crt`. It will also update the root-ca database and serial files. The output certificate `email-ca.crt` should now be created.

Verify the Email CA certificate:

```bash
openssl x509 -noout -text -in ./ca/email-ca/email-ca.crt
```

Check that:

- Issuer is “Cross Solutions Root CA”; Subject is “Cross Solutions Email CA”.
- Basic Constraints: CA:TRUE, pathlen:0 (critical).
- Key Usage: keyCertSign, cRLSign (critical).
- Extended Key Usage: emailProtection (should be present, not marked critical in this case).
- Name Constraints: none (we didn’t set any for email).
- AKI is present (should match root’s SKI), SKI is present (hash of this key).
- AIA: should contain “CA Issuers” URL pointing to http://pki.cross.solutions/root-ca.crt (from issuer_info in root config).
- CRL DP: should point to http://pki.cross.solutions/root-ca.crl (from crl_info in root config).

If all looks good, the Email CA cert is ready.

Repeat similar steps for the other intermediates:

**C. CSR for Software CA:**

```bash
openssl req -new -engine pkcs11 -keyform engine \
    -key "pkcs11:object=Cross Solutions Software CA;type=private" \
    -sha512 -config software-ca.conf -extensions ca_reqext \
    -out ./ca/software-ca/software-ca.csr
```

**Sign Software CA with Root:**

```bash
openssl ca -engine pkcs11 -keyform engine \
    -config root-ca.conf -extensions code_ca_ext \
    -in ./ca/software-ca/software-ca.csr \
    -out ./ca/software-ca/software-ca.crt
```

After this, verify `software-ca.crt` has CA:TRUE, pathlen:0, EKU=codeSigning, etc.

**D. CSR for VPN CA:**

```bash
openssl req -new -engine pkcs11 -keyform engine \
    -key "pkcs11:object=Cross Solutions VPN CA;type=private" \
    -sha512 -config vpn-ca.conf -extensions ca_reqext \
    -out ./ca/vpn-ca/vpn-ca.csr
```

**Sign VPN CA with Root:**

```bash
openssl ca -engine pkcs11 -keyform engine \
    -config root-ca.conf -extensions vpn_ca_ext \
    -in ./ca/vpn-ca/vpn-ca.csr \
    -out ./ca/vpn-ca/vpn-ca.crt
```

Verify `vpn-ca.crt` for CA:TRUE, pathlen:0, EKU = clientAuth+serverAuth, etc.

**E. CSR for Lab TLS CA:**

```bash
openssl req -new -engine pkcs11 -keyform engine \
    -key "pkcs11:object=Cross Solutions Lab TLS CA;type=private" \
    -sha512 -config lab-tls-ca.conf -extensions ca_reqext \
    -out ./ca/lab-tls-ca/lab-tls-ca.csr
```

**Sign Lab TLS CA with Root:**

```bash
openssl ca -engine pkcs11 -keyform engine \
    -config root-ca.conf -extensions lab_tls_ca_ext \
    -in ./ca/lab-tls-ca/lab-tls-ca.csr \
    -out ./ca/lab-tls-ca/lab-tls-ca.crt
```

This is a critical step – we apply the `lab_tls_ca_ext` profile to include the Name Constraints for *.lab.cross.solutions and pathlen:1. Verify `lab-tls-ca.crt`:
- Subject: “Cross Solutions Lab TLS CA”; Issuer: Root.
- Basic Constraints: CA:TRUE, pathlen:1.
- Key Usage: keyCertSign, cRLSign.
- Extended Key Usage: serverAuth.
- Name Constraints: Permitted DNS=.lab.cross.solutions (critical).
- AKI, SKI present. AIA (CA Issuers) should point to root-ca.crt, CRL DP to root-ca.crl.

At this point, all Tier-2 CA certificates are issued by the Root. The root CA’s job is done (it can now be stored safely offline). The intermediate certs (and their private keys in the HSM) will be used to issue further certs.

### 5. Issue the Tier-3 Lab Core TLS CA Certificate

The Lab Core TLS CA is a subordinate of the Lab TLS CA, not the root. We will use the Lab TLS CA (which is offline by design, but we have its key on the HSM similarly) to sign the Lab Core TLS CA’s CSR.

**Generate CSR for Lab Core TLS CA:**

```bash
openssl req -new -engine pkcs11 -keyform engine \
    -key "pkcs11:object=Cross Solutions Lab Core TLS CA;type=private" \
    -sha512 -config lab-core-tls-ca.conf -extensions ca_reqext \
    -out ./ca/lab-core-tls-ca/lab-core-tls-ca.csr
```

Check the CSR to ensure it has CA:TRUE, pathlen:0, nameConstraints for core.lab (the CSR may include the extension request for nameConstraints, though note that OpenSSL’s `req` might or might not include the nameConstraints in the CSR – even if not, we will add it via the signing profile).

**Sign Lab Core TLS CA with Lab TLS CA:**

We use `openssl ca` but this time with the Lab TLS CA’s config. First, ensure the Lab TLS CA’s config is set up with its certificate and database. Place the `lab-tls-ca.crt` we got from root into `./ca/lab-tls-ca/lab-tls-ca.crt` as specified, and create the DB files:

```bash
touch ./ca/lab-tls-ca/db/lab-tls-ca.db
echo 1000 > ./ca/lab-tls-ca/db/lab-tls-ca.crt.srl
echo 1000 > ./ca/lab-tls-ca/db/lab-tls-ca.crl.srl
```

Also, copy the root certificate to a place where OpenSSL can find it if needed for chain building (like `./ca/lab-tls-ca/` or in OpenSSL’s CApath), because when using `openssl ca` for an intermediate, it may need the issuer cert (root) for AKI computation or outputting chain.

We will copy the root certificate to each subordinate CA directory:

```bash

echo ca/{root-ca,email-ca,software-ca,vpn-ca,lab-tls-ca,lab-core-tls-ca} | xargs -n 1 cp ca/root-ca/root-ca.crt
```

Typically, we ensure `certificate = lab-tls-ca.crt` is set and `copy_extensions` is handled – which we did.

Now run:

```bash
openssl ca -engine pkcs11 -keyform engine \
    -config lab-tls-ca.conf -extensions lab_sub_ca_ext \
    -in ./ca/lab-core-tls-ca/lab-core-tls-ca.csr \
    -out ./ca/lab-core-tls-ca/lab-core-tls-ca.crt
```

This loads the Lab TLS CA’s key via HSM engine and uses the `lab_sub_ca_ext` profile to sign the Lab Core CA. After execution, check `lab-core-tls-ca.crt`:

- Issuer: Cross Solutions Lab TLS CA; Subject: Cross Solutions Lab Core TLS CA.
- Basic Constraints: CA:TRUE, pathlen:0.
- KeyUsage: keyCertSign, cRLSign.
- EKU: serverAuth.
- Name Constraints: Permitted DNS=.core.lab.cross.solutions (critical).
- AIA: should point to lab-tls-ca.crt (the issuing CA’s cert URL).
- CRL DP: should point to lab-tls-ca.crl.

If all good, the Lab Core TLS CA certificate is ready. The Lab TLS CA’s database and serial are updated accordingly. The Lab TLS CA (issuer) can now be taken offline, as its work is done until maybe the Lab Core CA needs renewal or another sub-CA for lab is needed.

We have now built the full CA hierarchy:

```
Root CA (offline, HSM key) 
 ├── Email CA (offline, HSM)
 ├── Software CA (offline, HSM)
 ├── VPN CA (offline, HSM)
 └── Lab TLS CA (offline, HSM)
      └── Lab Core TLS CA (online, HSM)
````

At this stage, distribute the certificates appropriately:

- Trust Anchor: **root-ca.crt** should be securely installed in all client trust stores that need to trust this PKI.
- Intermediate Certs: **email-ca.crt**, **software-ca.crt**, **vpn-ca.crt**, **lab-tls-ca.crt**, **lab-core-tls-ca.crt** – these can be distributed with the chain or made available at `http://pki.cross.solutions/<name>.crt` as per AIA. For internal use, you might also push them to clients, but typically it’s enough if the root is trusted and AIA is reachable.

### 6. Issuing End-Entity Certificates

Now the Tier-2 CAs (Email, Software, VPN) and the Tier-3 CA (Lab Core TLS) can start issuing certificates for their respective purposes. We focus on the Lab Core TLS CA issuing a TLS server certificate as an example, and outline the others more briefly.


**Example: Issue a TLS Server Certificate from Lab TLS CA**

Generate a key + CSR like this (on the host or an admin box — not on the HSM):

```bash
# 1) End-entity key
openssl ecparam -name secp384r1 -genkey -noout -out nas.lab.key.pem

# 2) CSR with SAN = DNS:op.lab.cross.solutions
openssl req -new -sha512 -key nas.lab.key.pem -out nas.lab.csr.pem -subj "/C=US/O=Cross Solutions/CN=nas.lab.cross.solutions" -addext "subjectAltName = DNS:nas.lab.cross.solutions,IP:192.168.11.7"
```

Now sign the CSR with the CA:

```bash
openssl ca -engine pkcs11 -keyform engine -notext \
  -config lab-tls-ca.conf -extensions lab_tls_server_ext -batch \
  -in op.lab.csr.pem -out ./ca/lab-tls-ca/op.lab.crt.pem
```

After issuance, you can verify the SAN is present:

```bash
openssl x509 -noout -text -in ./ca/lab-tls-ca/op.lab.crt.pem | sed -n '/Subject Alternative Name/,+2p'
```

Make a chain file for the cert:
```bash
cat ./ca/lab-tls-ca/op.lab.crt.pem ./ca/lab-tls-ca/lab-tls-ca.crt > ./ca/nas.lab.fullchain.pem
```

**Notes**

- `-engine pkcs11 -keyform engine` loads your Nitrokey HSM key referenced in lab-tls-ca.conf (private_key = pkcs11:object=lab-tls-ca-key;type=private).
- `-extensions lab_tls_server_ext` applies the TLS server profile defined in lab-tls-ca.conf.
- `-batch` signs non‑interactively.
- The Lab TLS CA’s nameConstraints (`.lab.cross.solutions`) permit `op.lab.cross.solutions`, so issuance will pass constraints.

**Example: Issue a TLS Server Certificate from Lab Core TLS CA**

Suppose we need a certificate for a web server `host1.core.lab.cross.solutions`. The process:

- The server (or an admin) generates a key pair and CSR for `host1.core.lab.cross.solutions`.
  - This key can be generated on the server itself (not necessarily on the HSM unless that server also has an HSM – typically, only CA keys are on the HSM in this design).
  - Use OpenSSL to generate an EC key and CSR:
    ```bash
    openssl ecparam -genkey -name secp384r1 -out host1.key.pem
    openssl req -new -sha512 -key host1.key.pem -out host1.csr.pem \
        -subj "/C=US/O=Cross Solutions/CN=host1.core.lab.cross.solutions" \
        -reqexts SAN -config <(printf "[SAN]\nsubjectAltName=DNS:host1.core.lab.cross.solutions")
    ```
    This produces `host1.csr.pem` with the CN and a SAN (since CN alone is not relied on by modern standards).
- The Lab Core TLS CA (which is online) receives the CSR. The CA operator verifies the request (ensuring the CN/SAN are within `core.lab.cross.solutions`, which in this case they are – and our CA’s nameConstraints will anyway prevent issuance outside that).

To sign this CSR with the Lab Core TLS CA:

```bash
openssl ca -config lab-core-tls-ca.conf \
    -in host1.csr.pem -out host1.crt.pem
```

Because we set `default_ca = lab_core_tls_ca` and all parameters in `lab-core-tls-ca.conf`, this will:
- Use `lab-core-tls-ca.crt` and the HSM key via the `private_key` PKCS#11 URI.
- Apply the `server_ext` extensions by default (since we set `x509_extensions = server_ext`).
- Copy the SAN extension from the CSR (because `copy_extensions = copy`).
- Assign a serial number and output `host1.crt.pem`.

After this, `host1.crt.pem` is the certificate for the server. Verify it:

```bash
openssl x509 -noout -text -in host1.crt.pem
```

It should show:
- Issuer: Cross Solutions Lab Core TLS CA.
- Subject: CN=host1.core.lab.cross.solutions (plus O and C as provided).
- SAN: DNS:host1.core.lab.cross.solutions (from CSR).
- Basic Constraints: CA:FALSE.
- Key Usage: Digital Signature, Key Encipherment.
- EKU: TLS Web Server Authentication (serverAuth).
- CRL DP: points to http://pki.cross.solutions/lab-core-tls-ca.crl.
- AIA: points to http://pki.cross.solutions/lab-core-tls-ca.crt (the issuing CA cert). Optionally, for a production environment, one could also have an OCSP URL here if an OCSP responder is set up.

This server certificate can now be used on `host1`. The chain that host1’s server should present (in TLS handshake) will include its own cert and the Lab Core TLS CA cert (as the intermediate). Because the Lab TLS CA has a name constraint and is offline, it’s not needed in the chain for validation by clients if the clients have the root and intermediate chain properly. However, typically you would provide the entire chain up to the root:

- Some clients might not have the Lab Core CA cached, so provide Lab Core TLS CA and Lab TLS CA as chain certs, and rely on client having Root CA trusted.
- Alternatively, since AIA is present, clients could fetch lab-core-tls-ca.crt or lab-tls-ca.crt as needed. But it’s often better to supply all intermediate certs (except the root) during TLS handshake.

So on the server, you might concatenate host1.crt + lab-core-tls-ca.crt + lab-tls-ca.crt (and even other tier2 if needed, but lab-tls-ca was signed by root so including lab-tls and root might suffice). Actually, since lab-core’s issuer (lab-tls) is not provided by the server in handshake, the client might need to download it via AIA from `pki.cross.solutions`. If that URL is accessible to clients, they will fetch lab-tls-ca.crt. If not (internal network scenario), you should configure the server to send both lab-core and lab-tls intermediates.

**Revocation:** The Lab Core TLS CA, being online, should be configured to regularly issue CRLs (e.g., a cron job to run `openssl ca -config lab-core-tls-ca.conf -gencrl -out lab-core-tls-ca.crl` daily or whenever a cert is revoked). The CRL is then published at `http://pki.cross.solutions/lab-core-tls-ca.crl`. Clients (or at least enterprise network devices) can retrieve it to check revocation. The same applies for other CAs:

- The offline CAs (email, software, VPN, lab-tls) should also have CRLs. Even if they rarely revoke certificates, a CRL must be available (even an empty one) to satisfy clients that check CDPs. For each, you would run `openssl ca -config <ca>.conf -gencrl -out <ca>.crl` whenever needed (at least before the `default_crl_days` interval passes). For example, the Email CA CRL might be updated monthly. Since those CAs are offline, generate CRLs on the offline machine and then post the CRL file to the `base_url` location (e.g., place on a web server hosting `pki.cross.solutions`).
- The root CA should also have a CRL, though in a private PKI, root CA revocations (of intermediates) are hopefully never needed. Still, we configured it. You can generate an initial root CRL:
  ```bash
  openssl ca -config root-ca.conf -gencrl -out ./ca/root-ca/root-ca.crl
  ```
  This will produce a CRL (likely empty, listing no revoked certs) with a nextUpdate 1 year out (per default_crl_days=365). Publish root-ca.crl at the HTTP location.

**S/MIME and Code Signing issuance:**

- The Email CA can now issue S/MIME certs. Users or devices will generate CSRs (with their email addresses, etc.) and an operator will use `openssl ca -config email-ca.conf` to sign them. The process is similar: ensure `email-ca.conf` has the right `x509_extensions = email_usr_ext` (which it does) and run `openssl ca -config email-ca.conf -in user.csr -out user.crt`. The email CA being offline means the signing might be done on a secure machine with the HSM inserted only as needed.
- The Software CA issues code signing certs for developers or systems. The signing procedure is similar; ensure the CSR has the appropriate subject (e.g., CN = developer name or application) and then use `openssl ca -config software-ca.conf -in code.csr -out code.crt`. The resulting cert will have EKU=codeSigning, etc.
- The VPN CA issues certificates for VPN clients/servers. Likely, a script or enrollment process would generate a CSR on the client, then an operator (or an automated system if the HSM can be network-connected) uses `openssl ca -config vpn-ca.conf -in vpnclient.csr -out vpnclient.crt`. The certificate will have EKU clientAuth (and serverAuth if it’s a server cert CSR). One could separate profiles for client vs server by specifying `-extensions server_ext` or `-extensions client_ext` manually if needed (we defined `vpn_cert_ext` covering both usages by including both EKUs; if you want to issue a client-only cert, it’s acceptable that it has serverAuth EKU as well in internal VPN usage, or you can adjust to have two profiles).

**Final Compliance Check:** All certificates in this hierarchy conform to RFC 5280:

- All CA certs have Basic Constraints (critical, CA=true, with pathLen constraints).
- All CA and end-entity certs have appropriate Key Usage (critical) and Extended Key Usage (where needed).
- Name Constraints on the Lab CAs are critical (as required by RFC 5280) and limit the name space as intended.
- The use of EKU in intermediate CA certs to restrict their issuance is aligned with CA/Browser Forum and Apple requirements for publicly trusted hierarchies (even though this is a private PKI, we adopted the practice to improve security).
- The chain length and pathlen settings ensure no unexpected further delegation: all Tier-2 CAs except Lab TLS have pathlen=0, and Lab TLS CA has pathlen=1 to allow only one subordinate CA, which is Lab Core. Lab Core has pathlen=0. The root’s pathlen=2 allows exactly that chain depth.
- Default cryptographic algorithms are strong: P-384 keys, SHA-512 for signatures. This meets modern security requirements (and exceeds baseline requirements which allow P-256 and SHA-256 minimum).
- Serial numbers are random 64-bit or greater by using `rand_serial = yes`, meeting CA/B Forum entropy requirements.
- The CA certificates also include Authority Key Identifier (keyID) and Subject Key Identifier (hash) for traceability, and CRL Distribution Points/AIA for revocation and chain discovery.
- CRLs are configured and should be made available as specified. Each CRL includes the AKI to identify which CA issued it.
- If this PKI were to be integrated into browsers or OS trust stores (even though private), it largely meets the baseline expectations (one notable difference: the intermediate certs include EKUs which is good for Apple but not strictly required by CAB forum except as a way to constrain usage; also, our email and VPN intermediates might not be applicable to public trust anyway).

Finally, back up all the certificates and HSM objects. The HSM holds the private keys; consider using the Nitrokey HSM’s backup mechanism (e.g., using a DKEK keyset and the Smart Card Shell or PKCS#11 backup functions) to have a secondary copy of keys in case the token is lost or damaged. Store the root and offline intermediate HSM devices in secure storage when not in use (since they are “always-offline”, only connect them to sign as needed in a controlled environment).

Your three-tier PKI with Nitrokey HSM protection is now set up. All private keys are hardware-protected, and the configuration files provided can be reused for certificate issuance and lifecycle management (renewals, CRL issuances, etc.).

For reference and further reading, consult the OpenSSL PKI Tutorial by Stefan H. Holek for configuration strategies, as well as the RFC 5280 and CA/Browser Forum Baseline Requirements for specific details on each extension and policy used. The Nitrokey documentation and community forums are also helpful for HSM-specific tips (such as using OpenSSL with PKCS#11). With this setup, you have a robust, compliant PKI suitable for internal use cases like secure email, code signing, VPN authentication, and TLS with constrained subdomains.

### 7. Adding Root CA to system/browser trust store

```bash
sudo cp ca/lab-tls-ca/lab-tls-ca.crt /etc/pki/ca-trust/source/anchors/cross-solutions-lab-tls-ca.crt
sudo update-ca-trust extract
```