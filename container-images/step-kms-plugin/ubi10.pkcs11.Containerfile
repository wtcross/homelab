# Minimal step-kms-plugin image with PKCS#11 support
# Contains step-kms-plugin and step-cli for HSM key and certificate operations

FROM registry.access.redhat.com/ubi10/ubi AS kms-builder

RUN dnf install -y \
    --nodocs \
    --enablerepo=codeready-builder-for-rhel-10-x86_64-rpms \
    git make gcc pkgconf golang pcsc-lite-devel \
    && dnf clean all

ARG STEP_KMS_PLUGIN_TAG
RUN git clone --branch "${STEP_KMS_PLUGIN_TAG}" --single-branch --depth 1 https://github.com/smallstep/step-kms-plugin.git /opt/app-root/src/step-kms-plugin
WORKDIR /opt/app-root/src/step-kms-plugin

RUN make V=1 build

# Build step-cli for certificate commands
FROM registry.access.redhat.com/ubi10/go-toolset AS cli-builder

ARG STEP_CLI_TAG
RUN git clone --branch "${STEP_CLI_TAG}" --single-branch --depth 1 https://github.com/smallstep/cli.git /opt/app-root/src/step-cli
WORKDIR /opt/app-root/src/step-cli
RUN go mod download

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=0 \
    make V=1 bin/step

# Create minimal rootfs with p11-kit client libraries
FROM registry.access.redhat.com/ubi10/ubi AS rootfs-builder

RUN mkdir -p /mnt/rootfs
RUN mkdir -p /mnt/rootfs/usr/lib64 /mnt/rootfs/usr/bin /mnt/rootfs/usr/sbin /mnt/rootfs/usr/lib \
    && ln -s usr/lib64 /mnt/rootfs/lib64 \
    && ln -s usr/bin   /mnt/rootfs/bin \
    && ln -s usr/sbin  /mnt/rootfs/sbin \
    && ln -s usr/lib   /mnt/rootfs/lib

RUN dnf install -y \
    --nodocs \
    --installroot /mnt/rootfs \
    --releasever=10 \
    --setopt=install_weak_deps=false \
    p11-kit gnutls-utils \
    && dnf clean all --installroot /mnt/rootfs
RUN rm -rf /mnt/rootfs/var/cache/* /mnt/rootfs/var/log/*

# Create step user for OpenShift compatibility
RUN useradd --root /mnt/rootfs -m -d /home/step -s /sbin/nologin -u 1001 step \
    && chown -R 1001:0 /mnt/rootfs/home/step \
    && chmod -R g+w /mnt/rootfs/home/step

# Create PKCS#11 socket mount point
RUN mkdir -p /mnt/rootfs/run/pkcs11-socket \
    && chown 1001:0 /mnt/rootfs/run/pkcs11-socket \
    && chmod 755 /mnt/rootfs/run/pkcs11-socket

FROM registry.access.redhat.com/ubi10/ubi-micro

COPY --from=rootfs-builder /mnt/rootfs /
COPY --from=kms-builder /opt/app-root/src/step-kms-plugin/bin/step-kms-plugin /usr/local/bin/step-kms-plugin
COPY --from=cli-builder /opt/app-root/src/step-cli/bin/step /usr/local/bin/step

ENV P11_KIT_SERVER_ADDRESS="unix:path=/run/pkcs11-socket"

USER 1001
WORKDIR /home/step
