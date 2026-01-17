FROM registry.access.redhat.com/ubi10/go-toolset AS builder

ARG TAG
RUN git clone --branch "${TAG}" --single-branch --depth 1 https://github.com/smallstep/cli.git /opt/app-root/src/step-cli
WORKDIR /opt/app-root/src/step-cli
RUN go mod download

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=0 \
    make V=1 bin/step

FROM registry.access.redhat.com/ubi10/ubi-micro

COPY --from=builder /opt/app-root/src/step-cli/bin/step /usr/bin/step

LABEL io.k8s.display-name="Step CLI" \
      io.k8s.description="CLI tool for building, operating, and automating Public Key Infrastructure (PKI) systems and workflows. It's also a client for the step-ca online Certificate Authority (CA) server."
