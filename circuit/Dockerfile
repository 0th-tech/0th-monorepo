FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG CIRCOM_VERSION=v2.2.3
RUN curl -fsSL -o /usr/local/bin/circom \
    https://github.com/iden3/circom/releases/download/${CIRCOM_VERSION}/circom-linux-amd64 \
    && chmod +x /usr/local/bin/circom \
    && circom --version

WORKDIR /work
