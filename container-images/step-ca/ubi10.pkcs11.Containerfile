# Minimal step-ca image with PKCS#11 support
# Uses p11-kit client libraries to connect to a PKCS#11 socket for private key operations

FROM registry.access.redhat.com/ubi10/ubi AS ca-builder

RUN dnf install -y \
    --nodocs \
    --enablerepo=codeready-builder-for-rhel-10-x86_64-rpms \
    git make gcc pkgconf golang pcsc-lite-devel \
    && dnf clean all

ARG STEP_CA_GIT_TAG
RUN git clone --branch "${STEP_CA_GIT_TAG}" --single-branch --depth 1 https://github.com/smallstep/certificates.git /opt/app-root/src/certificates
WORKDIR /opt/app-root/src/certificates

RUN make V=1 GO_ENVS="CGO_ENABLED=1" bin/step-ca
RUN setcap CAP_NET_BIND_SERVICE=+eip bin/step-ca

# Build step CLI for provisioner/admin setup
FROM registry.access.redhat.com/ubi10/go-toolset AS cli-builder

ARG STEP_CLI_GIT_TAG
RUN git clone --branch "${STEP_CLI_GIT_TAG}" --single-branch --depth 1 https://github.com/smallstep/cli.git /opt/app-root/src/step-cli
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
    bash p11-kit shadow-utils coreutils-single jq \
    && dnf clean all --installroot /mnt/rootfs
RUN rm -rf /mnt/rootfs/var/cache/* /mnt/rootfs/var/log/*

# Create step user for OpenShift compatibility
RUN useradd --root /mnt/rootfs -m -d /home/step -s /sbin/nologin -u 1001 step \
    && mkdir -p /mnt/rootfs/home/step/.step/config \
    && mkdir -p /mnt/rootfs/home/step/.step/secrets \
    && chown -R 1001:0 /mnt/rootfs/home/step \
    && chmod -R g+w /mnt/rootfs/home/step

# Create PKCS#11 socket mount point and secrets directory
RUN mkdir -p /mnt/rootfs/run/pkcs11-socket /mnt/rootfs/run/secrets \
    && chown 1001:0 /mnt/rootfs/run/pkcs11-socket /mnt/rootfs/run/secrets \
    && chmod 755 /mnt/rootfs/run/pkcs11-socket /mnt/rootfs/run/secrets

FROM registry.access.redhat.com/ubi10/ubi-micro

COPY --from=rootfs-builder /mnt/rootfs /
COPY --from=ca-builder /opt/app-root/src/certificates/bin/step-ca /usr/local/bin/step-ca
COPY --from=cli-builder /opt/app-root/src/step-cli/bin/step /usr/local/bin/step
COPY entrypoint.sh /home/step/entrypoint.sh

ENV STEPPATH="/home/step/.step"
ENV STEP_CA_ADDRESS=":9000"
ENV STEP_INTERMEDIATE_CERT_FILE="/run/secrets/intermediate.crt"
ENV STEP_ROOT_CERT_FILE="/run/secrets/root.crt"
ENV P11_KIT_SERVER_ADDRESS="unix:path=/run/pkcs11-socket"

USER 1001
WORKDIR /home/step

VOLUME ["/home/step/.step"]
STOPSIGNAL SIGTERM

ENTRYPOINT ["/bin/bash", "/home/step/entrypoint.sh"]
CMD ["/usr/local/bin/step-ca", "/home/step/.step/config/ca.json"]
EXPOSE 9000
