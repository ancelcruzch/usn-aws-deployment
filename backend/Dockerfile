# syntax=docker/dockerfile:1
# Backend Spring Boot. Build multi-stage:
#   1) build: compila con Maven (JDK) aprovechando la caché de dependencias.
#   2) runtime: solo JRE + el artefacto, usuario sin privilegios.

############################ 1. Build ############################
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Dependencias primero: esta capa solo se reconstruye si cambia pom.xml.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

# Código fuente (los tests se ejecutan en el pipeline de CI, no aquí).
COPY src src
RUN mvn -B -q -DskipTests package \
    && cp target/*.war /app/app.war

############################ 2. Runtime ##########################
FROM eclipse-temurin:17-jre-alpine

LABEL org.opencontainers.image.title="usn-backend" \
      org.opencontainers.image.description="API REST de Universe Social Network (Spring Boot)"

# Usuario sin privilegios con UID numérico fijo: Kubernetes (runAsNonRoot)
# solo puede verificar que no es root si el USER es numérico.
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app
WORKDIR /app

COPY --from=build --chown=app:app /app/app.war app.war

USER 10001:10001
EXPOSE 5000

# Memoria según el límite del contenedor (Kubernetes resources.limits).
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD ["wget", "-qO-", "http://127.0.0.1:5000/actuator/health/liveness"]

ENTRYPOINT ["java", "-jar", "/app/app.war"]
