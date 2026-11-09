# syntax=docker/dockerfile:1
# Frontend React. Build multi-stage:
#   1) build: compila la app con Node.
#   2) runtime: nginx sin privilegios sirve los archivos y hace de proxy
#      hacia backend, socket y ai-service (ver nginx/default.conf).

############################ 1. Build ############################
FROM node:20-alpine AS build
WORKDIR /app

# Dependencias primero (capa en caché mientras no cambie package-lock.json).
COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps --no-audit --no-fund

COPY public public
COPY src src

# URLs relativas: el navegador llama al mismo origen y nginx reenvía.
# La misma imagen sirve para cualquier entorno (local, EKS) sin recompilar.
ARG REACT_APP_API_URL=/api
ARG REACT_APP_PUBLIC_FOLDER=/api/images/
ARG REACT_APP_SOCKET_URL=/
ARG REACT_APP_AI_URL=/ai
ENV REACT_APP_API_URL=$REACT_APP_API_URL \
    REACT_APP_PUBLIC_FOLDER=$REACT_APP_PUBLIC_FOLDER \
    REACT_APP_SOCKET_URL=$REACT_APP_SOCKET_URL \
    REACT_APP_AI_URL=$REACT_APP_AI_URL \
    GENERATE_SOURCEMAP=false
RUN npm run build

############################ 2. Runtime ##########################
# Imagen oficial de nginx que corre como usuario no-root (UID 101), puerto 8080.
FROM nginxinc/nginx-unprivileged:1.27-alpine

LABEL org.opencontainers.image.title="usn-frontend" \
      org.opencontainers.image.description="Frontend React de Universe Social Network servido por nginx"

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["wget", "-qO-", "http://127.0.0.1:8080/healthz"]
