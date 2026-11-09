# Manifiestos de Kubernetes (EKS)

Despliegue de Universe Social Network en el namespace `usn` del cluster
`usn-cluster`. Los aplica automáticamente el workflow **CD**
(`.github/workflows/cd.yml`) en cada merge a `main`.

## Arquitectura

```text
Internet ──► Service frontend (LoadBalancer :80) ──► nginx (2-4 pods, HPA)
                                                       ├─ /           → React
                                                       ├─ /api/       → Service backend :5000 ──► Spring Boot (2-6 pods, HPA) ──► Amazon RDS
                                                       ├─ /socket.io/ → Service socket :8800  ──► Socket.io (1 pod)
                                                       └─ /ai/        → Service ai-service :8000 ──► FastAPI (1-3 pods, HPA)
```

Solo el frontend es público; los demás Services son `ClusterIP` (internos).

Las carpetas y los archivos están **numerados en el orden en que se aplican**:

```text
k8s/
├── 01-backend/
│   ├── 01-configmap.yaml      Configuración no sensible (JVM, Hibernate, logs)
│   ├── 02-service.yaml        Service ClusterIP :5000
│   └── 03-deployment.yaml     Spring Boot (probes, recursos, secretos)
├── 02-socket/
│   ├── 01-service.yaml        Service ClusterIP :8800
│   └── 02-deployment.yaml     Socket.io (1 réplica)
├── 03-ai-service/
│   ├── 01-service.yaml        Service ClusterIP :8000
│   └── 02-deployment.yaml     FastAPI
├── 04-frontend/               (después de 01-03: nginx necesita esos Services al arrancar)
│   ├── 01-service.yaml        Service LoadBalancer :80 (único acceso público)
│   └── 02-deployment.yaml     nginx + React
└── 05-hpa/                    (al final: escala los Deployments ya creados)
    ├── 01-backend-hpa.yaml    2 a 6 réplicas, CPU 60 %
    ├── 02-frontend-hpa.yaml   2 a 4 réplicas, CPU 70 %
    └── 03-ai-service-hpa.yaml 1 a 3 réplicas, CPU 70 %
```

El CD aplica las carpetas `k8s/NN-*` en orden numérico; una carpeta nueva
(por ejemplo `06-...`) se aplica automáticamente al final.

## Configuración y secretos

| Recurso | Tipo | Contenido | Quién lo crea |
| --- | --- | --- | --- |
| `backend-config` | ConfigMap | Opciones de JVM, Hibernate y logging | Este repositorio |
| `db-credentials` | Secret | `SPRING_DATASOURCE_URL`, `USERNAME`, `PASSWORD` de RDS | CD, desde AWS Secrets Manager |
| `cloudinary-credentials` | Secret (opcional) | `CLOUDINARY_*` | CD, si existen los GitHub Secrets |

Ningún secreto está en el repositorio.

## Decisiones

- **Imágenes**: los manifiestos usan el marcador `ECR_REGISTRY/usn-<servicio>:IMAGE_TAG`;
  el CD lo reemplaza por la imagen recién publicada en ECR (`sha-<commit>`).
- **Probes**:
  - backend: `startupProbe` (Spring Boot tarda en arrancar, hasta 3 minutos),
    `livenessProbe` (`/actuator/health/liveness`: si falla, se reinicia el
    contenedor) y `readinessProbe` (`/actuator/health/readiness`, que incluye
    la conexión a RDS: si falla, el pod deja de recibir tráfico).
  - frontend: `/healthz`; socket y ai-service: `/health`.
- **Recursos**: `requests` (lo que se reserva y la base del cálculo del HPA) y
  `limits` (máximo). El heap de la JVM se ajusta al límite de memoria
  (`MaxRAMPercentage=75`).
- **Réplicas**: las fija el HPA, no el Deployment; así un nuevo despliegue no
  anula el escalado. `topologySpreadConstraints` reparte las réplicas entre los
  nodos.
- **Actualizaciones sin cortes**: `RollingUpdate` con `maxUnavailable: 0`.
- **Seguridad**: contenedores sin root, sin escalada de privilegios,
  capabilities eliminadas y perfil seccomp por defecto.
- **socket con 1 réplica**: guarda en memoria los usuarios conectados; escalarlo
  requeriría sticky sessions y un adaptador compartido (Redis).

## Despliegue manual (alternativa al CD)

Requiere la capa `platform` creada y kubectl configurado
(`aws eks update-kubeconfig --region us-east-2 --name usn-cluster`). Hay que
reemplazar los marcadores de imagen; el CD lo hace automáticamente.

```bash
kubectl apply -f k8s/01-backend
kubectl apply -f k8s/02-socket
kubectl apply -f k8s/03-ai-service
kubectl apply -f k8s/04-frontend
kubectl apply -f k8s/05-hpa
kubectl -n usn get pods,svc,hpa
```

## Evidencias para la demo

**Estado y URL de la aplicación**

```bash
kubectl -n usn get deployments,pods,services,hpa -o wide
kubectl -n usn get service frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Recuperación ante fallos** (4.7): borrar un pod y ver que Kubernetes lo
recrea; la aplicación sigue respondiendo gracias a la otra réplica.

```bash
kubectl -n usn get pods -l app=backend -w          # en otra terminal
kubectl -n usn delete $(kubectl -n usn get pod -l app=backend -o name | head -1)
```

Fallo del proceso dentro del contenedor (lo detecta la livenessProbe y
aumenta `RESTARTS`):

```bash
kubectl -n usn exec deploy/ai-service -- kill 1
kubectl -n usn get pods -l app=ai-service
```

**Autoscaling** (4.8): durante la prueba de carga.

```bash
kubectl -n usn get hpa -w
kubectl -n usn top pods
```

**Eventos y logs** (4.9):

```bash
kubectl -n usn get events --sort-by=.lastTimestamp | tail -20
kubectl -n usn logs deploy/backend --tail=50
```

Las métricas y los logs históricos están en el dashboard de CloudWatch
(`terraform output cloudwatch_dashboard_url` en la capa platform).
