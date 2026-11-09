# USN AWS Deployment

Proyecto integrador de Cloud Computing: desarrollo, automatización y operación
de **Universe Social Network (USN)**, una red social cloud-native desplegada en
Amazon Web Services.

## Componentes de la aplicación

| Servicio | Carpeta | Tecnología | Puerto | Función |
| --- | --- | --- | --- | --- |
| Frontend | `client/` | React 18 | 3000 | Interfaz web |
| Backend | `backend/` | Spring Boot 3.2 (Java 17) | 5000 | API REST: usuarios, posts, chat, notificaciones (JWT) |
| Socket | `socket/` | Node.js + Socket.io | 8800 | Mensajes y notificaciones en tiempo real |
| AI service | `ai-service/` | Python + FastAPI | 8000 | Análisis de sentimiento y moderación de contenido |
| Base de datos | — | MySQL 8 | 3306 | Local: contenedor. AWS: **Amazon RDS** |

Las imágenes que suben los usuarios se guardan en **Cloudinary** (servicio
externo), por lo que el backend no guarda estado en disco y puede escalar
horizontalmente.

## Arquitectura en AWS

```text
GitHub ──push/PR──► GitHub Actions ──► Amazon ECR (imágenes) ──► Amazon EKS (us-east-2)
                    (CI / CD)                                     ├─ frontend, backend, socket, ai-service
                                                                  ├─ HPA + metrics-server
                                                                  └─ CloudWatch Container Insights
                                                     Amazon RDS MySQL (subred privada)
Infraestructura: Terraform (infrastructure/terraform)
```

Detalle de la infraestructura, decisiones de diseño, costos y procedimientos
para crear, actualizar y destruir el entorno:
[infrastructure/terraform/README.md](infrastructure/terraform/README.md).

## Estructura del repositorio

```text
usn-aws-deployment/
├── backend/                  API Spring Boot (Maven)
├── client/                   Frontend React
├── socket/                   Servidor Socket.io
├── ai-service/               Microservicio FastAPI
├── infrastructure/terraform/ Infraestructura como código (AWS)
├── .github/workflows/        Pipelines de GitHub Actions (CI/CD)
├── docker-compose.yml        Entorno de desarrollo local
├── init.sql                  Esquema inicial para MySQL local
└── .env.example              Plantilla de variables locales
```

## Ejecución local (desarrollo)

Requisitos: Docker Desktop.

```bash
cp .env.example .env          # completar MYSQL_ROOT_PASSWORD (y Cloudinary, opcional)
docker compose up --build
```

| Servicio | URL |
| --- | --- |
| Frontend | <http://localhost:3000> |
| Backend | <http://localhost:5001> |
| Socket | <http://localhost:8800/health> |
| AI service | <http://localhost:8000/docs> |

Para detener: `docker compose down` (agregar `-v` para borrar también los datos
de MySQL).

## Pruebas automatizadas

| Servicio | Tipo | Herramientas | Qué cubre |
| --- | --- | --- | --- |
| Backend | Unitarias (`*Test.java`, 139) | JUnit 5, Mockito | Controladores, servicios y modelos aislados |
| Backend | Integración (`*IT.java`) | Spring Boot Test, Testcontainers (MySQL 8 real) | API completa: health, registro/login, posts, likes, timeline, seguridad |
| AI service | Unitarias / API | pytest, FastAPI TestClient | Reglas de sentimiento y moderación, validación, estadísticas |

Requisitos: Java 17 y Docker en ejecución (Testcontainers crea un MySQL desechable;
no se necesita una base de datos instalada).

```bash
# Backend: unitarias + integración + cobertura
cd backend && ./mvnw verify

# AI service: análisis estático + pruebas + cobertura
cd ai-service
pip install -r requirements-dev.txt
ruff check . && ruff format --check .
pytest --junitxml=reports/junit.xml --cov=main --cov-report=html:reports/coverage
```

| Reporte | Ubicación |
| --- | --- |
| JUnit unitarias (backend) | `backend/target/surefire-reports/` |
| JUnit integración (backend) | `backend/target/failsafe-reports/` |
| Cobertura unitarias / integración (backend) | `backend/target/site/jacoco/` y `backend/target/site/jacoco-it/` |
| JUnit y cobertura (AI service) | `ai-service/reports/` |

En GitHub Actions las pruebas se ejecutan en cada Pull Request y sus reportes
se publican en la ejecución del workflow.

## Despliegue en AWS

1. Infraestructura: ver [infrastructure/terraform/README.md](infrastructure/terraform/README.md)
   (capa `base` una vez; capa `platform` en cada sesión de trabajo).
2. Aplicación: el workflow **CD** (`.github/workflows/cd.yml`) se ejecuta en
   cada merge a `main`: construye las imágenes, las publica en ECR con el SHA
   del commit, las despliega en EKS y verifica que la aplicación responda.

## Gestión de credenciales

- Ninguna credencial se guarda en el repositorio: `.env` está ignorado por Git.
- En AWS, la contraseña de la base de datos la genera Terraform y se guarda en
  Secrets Manager; el pipeline de CD la entrega al backend como Secret de
  Kubernetes.
- GitHub Actions usa un usuario IAM con permisos mínimos, cuyas claves se
  guardan como GitHub Secrets cifrados.

## Flujo de trabajo con Git

- `main`: rama protegida; solo recibe cambios mediante Pull Request aprobado y
  con los checks de CI en verde.
- Cada cambio se desarrolla en una rama `feature/<descripción>` creada desde
  `main` actualizado.
