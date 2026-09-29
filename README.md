# USN AWS Deployment

Proyecto académico para contenerizar y desplegar una aplicación de red social en Amazon Web Services.

La aplicación original utiliza:

- React para el frontend.
- Spring Boot para el backend.
- MySQL como base de datos.
- Docker y Docker Compose para el entorno local.
- Kubernetes mediante Amazon EKS para el despliegue.
- Amazon ECR para almacenar las imágenes Docker.
- Terraform para crear la infraestructura en AWS.

## Objetivo

El objetivo es ejecutar primero la aplicación localmente con Docker Compose y después desplegarla en Amazon EKS utilizando infraestructura como código.

El servicio de chat en tiempo real no forma parte del alcance inicial.

## Flujo de despliegue

```text
Aplicación local
      ↓
Docker Compose
      ↓
Imágenes Docker
      ↓
Amazon ECR
      ↓
Amazon EKS
```

## Estructura prevista

```text
usn-aws-deployment/
├── backend/
├── client/
├── docker-compose.yml
├── infrastructure/
│   └── terraform/
├── kubernetes/
└── README.md
```

## Estrategia de ramas

- `main`: código revisado y estable.
- `feature/import-application`: importación y limpieza de la aplicación.
- `feature/local-docker-compose`: ejecución local con Docker Compose.
- `feature/terraform-eks`: infraestructura de AWS con Terraform.
- `feature/kubernetes-manifests`: recursos de Kubernetes para EKS.

