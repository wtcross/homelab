FROM registry.access.redhat.com/ubi10/ubi AS builder

RUN dnf install -y \
    --nodocs \
    --enablerepo=codeready-builder-for-rhel-10-x86_64-rpms \
    git make gcc pkgconf golang pcsc-lite-libs \
    && dnf clean all

ARG TAG
RUN git clone --branch "${TAG}" --single-branch --depth 1 https://github.com/smallstep/certificates.git /opt/app-root/src/certificates
WORKDIR /opt/app-root/src/certificates

RUN make V=1 bin/step-ca
RUN setcap CAP_NET_BIND_SERVICE=+eip bin/step-ca

RUN mkdir -p /mnt/rootfs

RUN dnf install -y \
    --nodocs \
    --installroot /mnt/rootfs \
    --releasever=10 \
    --setopt=install_weak_deps=false \
    --enablerepo=codeready-builder-for-rhel-10-x86_64-rpms \
    opensc pcsc-lite gnutls-utils pcsc-lite-libs p11-kit \
    bash grep coreutils-single shadow-utils \
    && dnf clean all --installroot /mnt/rootfs

RUN useradd --root /mnt/rootfs -m -d /home/step -s /bin/bash -u 1000 step \
    && mkdir -p /mnt/rootfs/run/pcscd \
    && mkdir -p /mnt/rootfs/home/step/config \
    && mkdir -p /mnt/rootfs/home/step/secrets \
    && chown -R 1000:0 /mnt/rootfs/home/step \
    && chmod -R g+w /mnt/rootfs/home/step \
    && chown -R 1000:0 /mnt/rootfs/run/pcscd \
    && chmod -R g+w /mnt/rootfs/run/pcscd

FROM ghcr.io/wtcross/step-kms-plugin:v0.16.0 AS kms
FROM ghcr.io/wtcross/step-cli:v0.29.0

COPY --from=builder /mnt/rootfs /
COPY --from=builder /opt/app-root/src/certificates/bin/step-ca /usr/local/bin/step-ca
COPY --from=kms /usr/bin/step-kms-plugin /usr/bin/step-kms-plugin

USER step

ENV CONFIGPATH="/home/step/config/ca.json"
ENV PWDPATH="/home/step/secrets/password"

VOLUME ["/home/step"]
STOPSIGNAL SIGTERM
HEALTHCHECK CMD step ca health 2>/dev/null | grep "^ok" >/dev/null

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["/usr/local/bin/step-ca", "--password-file", "/home/step/secrets/password", "/home/step/config/ca.json"]
