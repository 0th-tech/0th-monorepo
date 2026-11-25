FROM debian:trixie-slim

# Needed to build the C++ witness generator
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates g++ make libgmp-dev nlohmann-json3-dev nasm \
    && rm -rf /var/lib/apt/lists/*

ARG CIRCOM_VERSION=v2.2.3
RUN curl -fsSL -o /usr/local/bin/circom \
    https://github.com/iden3/circom/releases/download/${CIRCOM_VERSION}/circom-linux-amd64 \
    && chmod +x /usr/local/bin/circom \
    && circom --version

WORKDIR /work
