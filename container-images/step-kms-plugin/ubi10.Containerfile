FROM registry.access.redhat.com/ubi10/ubi AS builder

RUN dnf install -y \
    --nodocs \
    --enablerepo=codeready-builder-for-rhel-10-x86_64-rpms \
    git make gcc pkgconf golang pcsc-lite-devel \
    && dnf clean all

ARG TAG
RUN git clone --branch "${TAG}" --single-branch --depth 1 https://github.com/smallstep/step-kms-plugin.git /opt/app-root/src/step-kms-plugin
WORKDIR /opt/app-root/src/step-kms-plugin

RUN make V=1 build

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
    bash grep coreutils-single shadow-utils pcsc-lite-libs p11-kit gnutls-utils p11-kit-server \
    && dnf clean all --installroot /mnt/rootfs
RUN rm -rf /mnt/rootfs/var/cache/*

RUN useradd --root /mnt/rootfs -m -d /home/step -s /bin/bash -u 1001 step

FROM ghcr.io/wtcross/step-cli:v0.29.0

COPY --from=builder /mnt/rootfs /
COPY --from=builder /opt/app-root/src/step-kms-plugin/bin/step-kms-plugin /usr/local/bin/step-kms-plugin

USER 1001
