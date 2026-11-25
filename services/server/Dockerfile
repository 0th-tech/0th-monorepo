FROM debian:trixie-slim AS rapidsnark
RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*
ADD --checksum=sha256:2ec59e3aa5ff498e862d60b3b7abdcd094ea484271750ec1ea14fb7c1305e423 \
    https://github.com/iden3/rapidsnark/releases/download/v0.0.8/rapidsnark-linux-x86_64-v0.0.8.zip \
    /tmp/rapidsnark.zip
RUN unzip -j /tmp/rapidsnark.zip '*/bin/prover' '*/bin/verifier' -d /rapidsnark

FROM node:26.13.1-slim

ARG PNPM_VERSION=12.21.0
RUN npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY services/server/package.json services/server/
RUN pnpm install --frozen-lockfile --prod --filter server

COPY --from=rapidsnark /rapidsnark/prover /usr/local/bin/rapidsnark
COPY circuit/release/login.zkey circuit/release/vk.json circuit/release/login-witness.dat circuit/release/
COPY --chmod=755 circuit/release/login-witness circuit/release/
ENV CIRCUIT_DIR=/app/circuit/release

# The image build fails unless login.zkey and vk.json come from the same make release run.
# A mismatched pair still makes proofs, but the on-chain verifier rejects it
RUN --mount=type=bind,source=circuit/fixtures,target=/fixtures \
    --mount=type=bind,from=rapidsnark,source=/rapidsnark,target=/rapidsnark \
    cd /tmp \
    && $CIRCUIT_DIR/login-witness /fixtures/input.json witness.wtns \
    && rapidsnark $CIRCUIT_DIR/login.zkey witness.wtns proof.json public.json \
    && /rapidsnark/verifier $CIRCUIT_DIR/vk.json public.json proof.json \
    && rm witness.wtns proof.json public.json

COPY services/server/src services/server/src

WORKDIR /app/services/server
USER node

CMD ["node", "src/main.ts"]
