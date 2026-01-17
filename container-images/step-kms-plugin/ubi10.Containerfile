FROM registry.access.redhat.com/ubi10/ubi AS builder

RUN dnf -y install --nodocs \
    git make gcc pkgconf golang \
    pcsc-lite-devel

ARG TAG
RUN git clone --branch "${TAG}" --single-branch --depth 1 https://github.com/smallstep/step-kms-plugin.git /opt/app-root/src/step-kms-plugin
WORKDIR /opt/app-root/src/step-kms-plugin

RUN make V=1 build

FROM ghcr.io/wtcross/step-cli:v0.29.0

COPY --from=builder /opt/app-root/src/step-kms-plugin/bin/step-kms-plugin /usr/bin/step-kms-plugin

LABEL io.k8s.display-name="step-kms-plugin" \
      io.k8s.description="This is a tool that helps manage keys and certificates on a cloud KMSs and HSMs. It can be used independently, or as a plugin for step."
