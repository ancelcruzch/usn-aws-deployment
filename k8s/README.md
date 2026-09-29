# Despliegue en Kubernetes (Amazon EKS)

Esta configuración despliega la arquitectura limpia de 3 capas:
1. **Base de Datos:** MySQL 8.0 con almacenamiento persistente (`PVC`).
2. **Backend:** API REST en Spring Boot 3.2.
3. **Frontend:** Aplicación web React expuesta con un `LoadBalancer` público de AWS.

## Pasos para desplegar en tu cluster de EKS:

### 1. Construir y subir las imágenes a Docker Hub o AWS ECR
```bash
# Backend
docker build -t tu-usuario-docker/social-backend:latest ./backend
docker push tu-usuario-docker/social-backend:latest

# Frontend
docker build -t tu-usuario-docker/social-frontend:latest ./client
docker push tu-usuario-docker/social-frontend:latest
```
*(Recuerda reemplazar `tu-usuario-docker` por tu usuario de Docker Hub en `03-backend.yaml` y `04-frontend.yaml`).*

### 2. Aplicar todos los manifiestos en Kubernetes
```bash
kubectl apply -f k8s/
```

### 3. Verificar el estado de los Pods y Servicios
```bash
kubectl get pods -n social-network
kubectl get svc -n social-network
```

### 4. Obtener la URL pública de AWS
En la salida de `kubectl get svc -n social-network`, copia la dirección en la columna `EXTERNAL-IP` de `frontend-service` (será una URL de AWS terminada en `.elb.amazonaws.com`) y ábrela en tu navegador.
