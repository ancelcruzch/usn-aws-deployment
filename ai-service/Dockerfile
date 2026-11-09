# syntax=docker/dockerfile:1
# Microservicio FastAPI. Imagen slim de Python, dependencias en capa cacheable
# y ejecución con un usuario sin privilegios.
FROM python:3.11-slim

LABEL org.opencontainers.image.title="usn-ai-service" \
      org.opencontainers.image.description="Análisis de sentimiento y moderación de Universe Social Network"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN useradd --create-home --uid 10001 app
WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY --chown=app:app main.py .

# UID numérico (requisito de runAsNonRoot en Kubernetes).
USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
