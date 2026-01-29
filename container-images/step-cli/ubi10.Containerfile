FROM registry.access.redhat.com/ubi10/go-toolset AS builder

ARG STEP_CLI_VERSION
ARG COSIGN_VERSION="3.0.4"
ARG COSIGN_SHA256="10dab2fd2170b5aa0d5c0673a9a2793304960220b314f6a873bf39c2f08287aa"
WORKDIR /opt/app-root/src

RUN curl -sSfL "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64" \
    -o cosign \
    && echo "${COSIGN_SHA256}  cosign" | sha256sum -c - \
    && chmod +x cosign

RUN curl -sSfL -O "https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/step_${STEP_CLI_VERSION}.tar.gz" \
    && curl -sSfL -O "https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/step_${STEP_CLI_VERSION}.tar.gz.sig" \
    && curl -sSfL -O "https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/step_${STEP_CLI_VERSION}.tar.gz.pem"

RUN ./cosign verify-blob \
    --certificate "step_${STEP_CLI_VERSION}.tar.gz.pem" \
    --signature "step_${STEP_CLI_VERSION}.tar.gz.sig" \
    --certificate-identity-regexp "https://github\.com/smallstep/workflows/.*" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    "step_${STEP_CLI_VERSION}.tar.gz"

RUN mkdir step-cli && tar -xzf "step_${STEP_CLI_VERSION}.tar.gz" -C step-cli

WORKDIR /opt/app-root/src/step-cli
RUN go mod download

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=0 \
    make V=1 bin/step

FROM registry.access.redhat.com/ubi10/ubi-micro

COPY --from=builder /opt/app-root/src/step-cli/bin/step /usr/local/bin/step

USER 1001
