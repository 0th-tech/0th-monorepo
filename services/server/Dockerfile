FROM node:26.13.1-slim

ARG PNPM_VERSION=12.21.0
RUN npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY services/server/package.json services/server/
RUN pnpm install --frozen-lockfile --prod --filter server

COPY circuit/release circuit/release
ENV CIRCUIT_DIR=/app/circuit/release

COPY services/server/src services/server/src

WORKDIR /app/services/server
USER node

CMD ["node", "src/main.ts"]
