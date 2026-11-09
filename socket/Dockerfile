# syntax=docker/dockerfile:1
# Servidor Socket.io (tiempo real). Imagen mínima de Node, sin dependencias de
# desarrollo y ejecutada con el usuario sin privilegios "node".
FROM node:20-alpine

LABEL org.opencontainers.image.title="usn-socket" \
      org.opencontainers.image.description="Servidor Socket.io de Universe Social Network"

ENV NODE_ENV=production
WORKDIR /app

# Instalación reproducible (package-lock.json) en una capa cacheable.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY --chown=node:node index.js ./

# Usuario "node" de la imagen base, por UID numérico (requisito de runAsNonRoot).
USER 1000:1000
EXPOSE 8800

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8800/health || exit 1

CMD ["node", "index.js"]
