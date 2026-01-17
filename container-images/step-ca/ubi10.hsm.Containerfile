FROM registry.access.redhat.com/ubi10/go-toolset AS builder

# Install dependencies to build step-ca with HSM support
RUN dnf -y install --nodocs \
    git make gcc pkgconf \
    pcsc-lite-libs


    git make gcc pkgconf \
    pcsc-lite-devel libcap-devel libcap \
    cmake libusb1-devel openssl-devel libedit-devel libcurl-devel \
    shadow-utils \
    tar gzip \
    && dnf clean all

# Install Go manually
RUN curl -L https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH=$PATH:/usr/local/go/bin

WORKDIR /src

# --- 1. Build step-ca ---
COPY . .
# Compile with CGO enabled (required for PKCS#11/HSM support)
RUN make V=1 GO_ENVS="CGO_ENABLED=1" bin/step-ca
# Set capability on the binary
RUN setcap CAP_NET_BIND_SERVICE=+eip bin/step-ca

# --- 2. Build Helper Binaries ---
# We build step-cli and step-kms-plugin from source to ensure they link
# correctly against UBI 10's glibc.

# Build step-kms-plugin
RUN git clone https://github.com/smallstep/step-kms-plugin.git /src/kms-plugin \
    && cd /src/kms-plugin \
    && go build -o step-kms-plugin ./cmd/step-kms-plugin

# Build step-cli
RUN git clone https://github.com/smallstep/cli.git /src/cli \
    && cd /src/cli \
    && make build \
    && mv bin/step /src/bin/step

# --- 3. Build YubiHSM PKCS#11 Module ---
# RHEL/UBI does not have yubihsm-pkcs11 in standard repos. We build from source.
# We use the release tarball to avoid needing 'gengetopt'.
RUN curl -L https://github.com/Yubico/yubihsm-shell/releases/download/${YUBIHSM_SHELL_VERSION}/yubihsm-shell-${YUBIHSM_SHELL_VERSION}.tar.gz | tar -xz -C /src \
    && cd /src/yubihsm-shell-${YUBIHSM_SHELL_VERSION} \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    && make -j$(nproc) \
    && make install DESTDIR=/src/yubihsm-install

# --- 4. Prepare Runtime Root Filesystem ---
# Since ubi-micro has no package manager, we create a rootfs here.
RUN mkdir -p /mnt/rootfs

# Install runtime RPMs into /mnt/rootfs
# - opensc, pcsc-lite, gnutls-utils, p11-kit: Smartcard/Crypto libraries
# - libusb1, libedit, openssl-libs: Runtime deps for YubiHSM
# - bash, grep, coreutils-single: Required for entrypoint and healthcheck
RUN dnf install --installroot /mnt/rootfs --releasever=10 --setopt=install_weak_deps=false --nodocs -y \
    opensc pcsc-lite gnutls-utils pcsc-lite-libs p11-kit \
    libusb1 libedit openssl-libs libcurl \
    bash grep coreutils-single \
    shadow-utils \
    && dnf clean all --installroot /mnt/rootfs

# Setup User and Directories in RootFS
# OpenShift Requirement: Directories must be owned by the root group (0) and
# writable by the group to support arbitrary user IDs.
RUN useradd --root /mnt/rootfs -m -d /home/step -s /bin/bash -u 1000 step \
    && mkdir -p /mnt/rootfs/run/pcscd \
    && mkdir -p /mnt/rootfs/home/step/config \
    && mkdir -p /mnt/rootfs/home/step/secrets \
    && chown -R 1000:0 /mnt/rootfs/home/step \
    && chmod -R g+w /mnt/rootfs/home/step \
    && chown -R 1000:0 /mnt/rootfs/run/pcscd \
    && chmod -R g+w /mnt/rootfs/run/pcscd

# -----------------------------------------------------------------------------
# Stage 2: Final Image
# Based on UBI 10 Micro for minimal footprint
# -----------------------------------------------------------------------------
FROM registry.access.redhat.com/ubi10/ubi-micro

# 1. Copy the populated root filesystem
COPY --from=builder /mnt/rootfs /

# 2. Copy Application Binaries
COPY --from=builder /src/bin/step-ca /usr/local/bin/step-ca
COPY --from=builder /src/bin/step /usr/local/bin/step
COPY --from=builder /src/kms-plugin/step-kms-plugin /usr/local/bin/step-kms-plugin

# 3. Copy YubiHSM Libraries (PKCS#11 module and dependencies)
COPY --from=builder /src/yubihsm-install/usr/lib64/pkcs11/yubihsm_pkcs11.so /usr/lib64/pkcs11/
COPY --from=builder /src/yubihsm-install/usr/lib64/libyubihsm* /usr/lib64/

# 4. Final Configuration
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER 1000

ENV CONFIGPATH="/home/step/config/ca.json"
ENV PWDPATH="/home/step/secrets/password"

VOLUME ["/home/step"]
STOPSIGNAL SIGTERM

# Healthcheck
HEALTHCHECK CMD step ca health 2>/dev/null | grep "^ok" >/dev/null

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["/usr/local/bin/step-ca", "--password-file", "/home/step/secrets/password", "/home/step/config/ca.json"]
