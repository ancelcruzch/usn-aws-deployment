# Universe Social Network (USN) - Despliegue en Kubernetes sobre AWS

Plataforma de red social basada en una arquitectura distribuida de microservicios, containerizada con Docker y orquestada mediante Kubernetes sobre Amazon Web Services (AWS). El sistema implementa gestion automatica de replicas, tolerancia a fallos mediante autocuracion (self-healing), persistencia de datos elástica y autoescalado horizontal (HPA) ante variaciones de carga.

> Para el despliegue 100% automatizado de la infraestructura en AWS mediante plantillas declarativas de Infraestructura como Codigo (IaC), consulte: [DEPLOYMENT_AWS.md](DEPLOYMENT_AWS.md).

---

## Tabla de Contenidos
1. [Arquitectura del Sistema](#1-arquitectura-del-sistema)
2. [Componentes y Replicas Gestionadas](#2-componentes-y-replicas-gestionadas)
3. [Estructura del Proyecto](#3-estructura-del-proyecto)
4. [Fase 1: Construccion y Publicacion de Imagenes Docker](#4-fase-1-construccion-y-publicacion-de-imagenes-docker)
5. [Fase 2: Configuracion del Cluster en AWS](#5-fase-2-configuracion-del-cluster-en-aws)
6. [Fase 3: Despliegue de la Infraestructura en Kubernetes](#6-fase-3-despliegue-de-la-infraestructura-en-kubernetes)
7. [Fase 4: Guia de Demostracion y Casos de Prueba](#7-fase-4-guia-de-demostracion-y-casos-de-prueba)
   - [Caso 1: Verificacion de Replicas y Balanceo de Carga](#caso-1-verificacion-de-replicas-y-balanceo-de-carga)
   - [Caso 2: Tolerancia a Fallos y Autocuracion (Self-Healing)](#caso-2-tolerancia-a-fallos-y-autocuracion-self-healing)
   - [Caso 3: Persistencia de Datos ante Caida de Contenedor Stateful](#caso-3-persistencia-de-datos-ante-caida-de-contenedor-stateful)
   - [Caso 4: Prueba de Estres y Autoescalado Horizontal (HPA)](#caso-4-prueba-de-estres-y-autoescalado-horizontal-hpa)
   - [Caso 5: Validacion del Microservicio de Inteligencia Artificial](#caso-5-validacion-del-microservicio-de-inteligencia-artificial)
   - [Caso 6: Actualizaciones sin Interrupcion de Servicio (Rolling Update)](#caso-6-actualizaciones-sin-interrupcion-de-servicio-rolling-update)
8. [Ejecucion Local para Desarrollo (Docker Compose)](#8-ejecucion-local-para-desarrollo-docker-compose)
9. [Fase 5: Eliminacion de Recursos en AWS](#9-fase-5-eliminacion-de-recursos-en-aws)

---

## 1. Arquitectura del Sistema

El sistema implementa una arquitectura desacoplada y poliglota compuesta por 4 microservicios de aplicacion y 1 base de datos relacional con almacenamiento persistente:

```text
                               [ INTERNET / CLIENTES ]
                                          |
                                          v
                            [ AWS Elastic Load Balancer ]
                                          |
            +-----------------------------+-----------------------------+-----------------------------+
            | (Puerto 80)                 | (Puerto 5000)               | (Puerto 8800)               | (Puerto 8000)
            v                             v                             v                             v
    [ Frontend Service ]          [ Backend Service ]           [ Socket Service ]            [ AI Service ]
            |                             |                             |                             |
      +-----+-----+                 +-----+-----+                 +-----+-----+                 +-----+-----+
      v           v                 v     v     v                 v           v                 v           v
   Pod Web 1   Pod Web 2         Pod 1  Pod 2 Pod 3            Pod WS 1    Pod WS 2          Pod AI 1    Pod AI 2
   (React 18)  (React 18)     (Spring Boot / Java 17)       (Node.js / Socket.io)         (Python / FastAPI)
                               (HPA: 3 a 6 replicas)
                                          |
                                          v (JDBC)
                                 [ MySQL Service ]
                                          |
                                          v
                                [ Pod MySQL 8.0 Engine ]
                                          |
                                          v
                            [ AWS EBS Persistent Volume ]
```

---

## 2. Componentes y Replicas Gestionadas

| Componente | Tecnologia | Replicas | Rol en el Sistema | Estrategia Kubernetes |
| :--- | :--- | :---: | :--- | :--- |
| **Frontend** | React 18, Redux Toolkit | 2 | Interfaz grafica de usuario web | Deployment distribuido con Service LoadBalancer publico. |
| **Backend Core** | Spring Boot 3, Java 17, JPA | 3 | API REST de usuarios, publicaciones y autenticacion JWT | Deployment con HPA por CPU, probes de salud y RollingUpdate. |
| **Socket Service** | Node.js, WebSockets, Socket.io | 2 | Comunicacion bidireccional y chat en tiempo real | Deployment con Readiness y Liveness probes sobre `/health`. |
| **AI Moderation** | Python 3.10, FastAPI, NLP | 2 | Analisis de sentimiento y moderacion de contenido | Deployment stateless con escalamiento horizontal independiente. |
| **Database** | MySQL 8.0 Engine | 1 | Persistencia relacional de datos | PersistentVolumeClaim vinculado a volumenes elasticos AWS EBS (5 GiB). |

---

## 3. Estructura del Proyecto

```text
universe_social_network_web_app/
|-- backend/                   # Microservicio REST Spring Boot (Java 17)
|   |-- src/main/java/         # Logica de negocio, controladores, seguridad JWT
|   |-- src/main/resources/    # Configuracion de conexion JDBC mediante variables de entorno
|   `-- Dockerfile             # Construccion multi-stage sobre Eclipse Temurin JDK 17
|-- client/                    # Aplicacion Frontend SPA en React 18
|   |-- src/api/               # Cliente HTTP Axios con configuracion dinamica de endpoint
|   |-- src/pages/             # Vistas de la aplicacion (Home, Auth, Profile, Chat)
|   `-- Dockerfile             # Construccion multi-stage con Node.js Alpine y servidor web
|-- socket/                    # Servidor WebSockets para Chat y Eventos en Tiempo Real
|   |-- index.js               # Enrutamiento de eventos, usuarios activos y endpoint /health
|   |-- package.json           # Dependencias de Socket.io y Express
|   `-- Dockerfile             # Contenedor optimizado en Node.js 18 Alpine
|-- ai-service/                # Microservicio de Inteligencia Artificial
|   |-- main.py                # Servidor FastAPI asincrono con motor de clasificacion NLP
|   |-- requirements.txt       # Dependencias de Python (FastAPI, Uvicorn, Pydantic)
|   `-- Dockerfile             # Contenedor en Python 3.10 Slim
|-- k8s/                       # Manifiestos declarativos de Kubernetes para AWS
|   |-- 00-namespace.yaml      # Aislamiento en el namespace 'usn'
|   |-- 01-config-secrets.yaml # Parametros de configuracion y credenciales encriptadas
|   |-- 02-mysql-init.yaml     # ConfigMap con esquemas DDL de inicializacion
|   |-- 03-mysql.yaml          # PersistentVolumeClaim (EBS) + Deployment + Service
|   |-- 04-backend.yaml        # Deployment (3 replicas) con limites de recursos + Service
|   |-- 05-socket.yaml         # Deployment (2 replicas) + Service
|   |-- 05-ai-service.yaml     # Deployment (2 replicas) + Service ClusterIP
|   |-- 06-frontend.yaml       # Deployment (2 replicas) + Service LoadBalancer
|   |-- 07-hpa.yaml            # Regla de autoescalado horizontal basada en utilizacion de CPU
|   `-- 08-stress-job.yaml     # Tarea batch para inyeccion de carga en pruebas de estres
|-- init.sql                   # Definicion DDL de tablas relacionales
|-- docker-compose.yml         # Orquestacion de contenedores para entorno de desarrollo local
`-- README.md                  # Manual tecnico y guia de evaluacion
```

---

## 4. Fase 1: Construccion y Publicacion de Imagenes Docker

Para que los nodos de Kubernetes en AWS puedan descargar las imagenes, estas deben publicarse en un registro publico como Docker Hub.

Ejecutar desde el directorio raiz del proyecto:

```powershell
# 1. Autenticacion en Docker Hub
docker login

# 2. Construccion y publicacion del Backend
docker build -t teriyaki08/usn-backend:latest ./backend
docker push teriyaki08/usn-backend:latest

# 3. Construccion y publicacion del Frontend
docker build -t teriyaki08/usn-frontend:latest ./client
docker push teriyaki08/usn-frontend:latest

# 4. Construccion y publicacion del Servidor Socket
docker build -t teriyaki08/usn-socket:latest ./socket
docker push teriyaki08/usn-socket:latest

# 5. Construccion y publicacion del Servicio de IA
docker build -t teriyaki08/usn-ai-service:latest ./ai-service
docker push teriyaki08/usn-ai-service:latest
```

*Nota: En caso de utilizar una cuenta diferente en Docker Hub, sustituir `ancelcruzch` por el nombre de usuario correspondiente y actualizar la propiedad `image:` en los manifiestos de la carpeta `k8s/`.*

---

## 5. Fase 2: Configuracion del Cluster en AWS

Seleccionar una de las siguientes dos alternativas segun los privilegios disponibles en la cuenta de AWS:

### Alternativa A: Amazon Elastic Kubernetes Service (EKS) Gestionado
Recomendada para cuentas con permisos administrativos completos.

1. Configurar credenciales locales de AWS:
   ```powershell
   aws configure
   ```

2. Crear el cluster y el grupo de nodos de trabajo mediante `eksctl`:
   ```powershell
   eksctl create cluster `
     --name usn-cluster `
     --region us-east-1 `
     --nodegroup-name standard-workers `
     --node-type t3.medium `
     --nodes 2 `
     --nodes-min 2 `
     --nodes-max 4 `
     --managed
   ```

3. Actualizar el contexto local de `kubectl`:
   ```powershell
   aws eks update-kubeconfig --region us-east-1 --name usn-cluster
   ```

### Alternativa B: Instancia EC2 con Distribucion k3s
Recomendada para cuentas educativas (AWS Academy / Learner Lab) con restricciones de IAM para el servicio EKS.

1. Lanzar una instancia EC2 con sistema operativo Ubuntu 22.04 LTS (tipo `t3.medium` o `t3.large`).
2. Configurar el Grupo de Seguridad de la instancia habilitando el trafico de entrada para los puertos: `80`, `3000`, `5000`, `8000`, `8800` y `6443`.
3. Conectarse mediante SSH a la instancia EC2 y ejecutar la instalacion de k3s:
   ```bash
   curl -sfL https://get.k3s.io | sh -
   sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
   sudo chown $USER ~/.kube/config
   ```

---

## 6. Fase 3: Despliegue de la Infraestructura en Kubernetes

Una vez establecida la conexion con el cluster de AWS, desplegar la totalidad de componentes con un unico comando declarativo:

```powershell
kubectl apply -f k8s/
```

### Proceso Automatizado que Ejecuta Kubernetes:
1. Creacion del namespace aislado `usn`.
2. Asignacion del almacenamiento persistente mediante `PersistentVolumeClaim` (5 GiB respaldados por AWS EBS).
3. Configuracion de variables de entorno y secretos con credenciales de base de datos y firmas JWT.
4. Despliegue del motor de base de datos MySQL con precarga de tablas DDL mediante ConfigMap.
5. Despliegue y verificacion de salud de los 4 microservicios en sus correspondientes replicas.
6. Solicitud de aprovisionamiento de un AWS Elastic Load Balancer para el servicio Frontend.

### Comandos de Verificacion:

```powershell
# Verificar el estado de todos los pods del namespace
kubectl get pods -n usn

# Verificar los servicios y direcciones publicas asignadas
kubectl get services -n usn
```

La direccion de acceso al sistema estara indicada en la columna `EXTERNAL-IP` del servicio `frontend-service`.

---

## 7. Fase 4: Guia de Demostracion y Casos de Prueba

La siguiente secuencia de casos practicos permite sustentar formalmente la gestion de contenedores, la tolerancia a fallos y la resiliencia del sistema ante un evaluador.

---

### Caso 1: Verificacion de Replicas y Balanceo de Carga

**Objetivo:** Demostrar que los microservicios se encuentran distribuidos en multiples instancias activas.

**Comando de ejecucion:**
```powershell
kubectl get pods -n usn -o wide
```

**Resultado esperado:**
El cluster debe reportar 10 pods operativos en paralelo:
- `backend-deployment-...` (3 replicas)
- `frontend-deployment-...` (2 replicas)
- `socket-deployment-...` (2 replicas)
- `ai-service-deployment-...` (2 replicas)
- `mysql-deployment-...` (1 pod)

**Explicacion tecnica:**
El objeto `Service` de Kubernetes distribuye equitativamente las solicitudes entrantes entre las direcciones IP internas de cada pod disponible mediante reglas de `iptables` y proxy de red.

---

### Caso 2: Tolerancia a Fallos y Autocuracion (Self-Healing)

**Objetivo:** Evidenciar que la eliminacion abrupta de un contenedor no degrada el servicio y activa la recuperacion automatica.

**Secuencia de prueba:**
1. Mantener la aplicacion web abierta en el navegador.
2. Identificar el identificador de uno de los pods del Backend:
   ```powershell
   kubectl get pods -n usn -l app=backend
   ```
3. Forzar la eliminacion del pod seleccionado:
   ```powershell
   kubectl delete pod <nombre-del-pod-backend> -n usn
   ```
4. Consultar inmediatamente el estado del cluster:
   ```powershell
   kubectl get pods -n usn -l app=backend
   ```

**Resultado esperado:**
- La navegacion del usuario en la red social continua sin interrupciones gracias a las 2 replicas restantes.
- Kubernetes detecta la discrepancia entre el estado actual y el deseado (`replicas: 3`) y crea un pod sustituto en menos de 3 segundos.

---

### Caso 3: Persistencia de Datos ante Caida de Contenedor Stateful

**Objetivo:** Comprobar que los datos persisten tras la destruccion total del contenedor de base de datos.

**Secuencia de prueba:**
1. Registrar un usuario o realizar una publicacion desde la interfaz web.
2. Destruir intencionalmente el pod de MySQL:
   ```powershell
   kubectl delete pod -l app=mysql -n usn
   ```
3. Supervisar la creacion del nuevo pod:
   ```powershell
   kubectl get pods -n usn -l app=mysql -w
   ```
4. Recargar la aplicacion web en el navegador.

**Resultado esperado:**
La informacion publicada permanece intacta. El nuevo pod de MySQL vuelve a montar el volumen `mysql-pvc`, el cual almacena los datos de forma independiente al ciclo de vida del contenedor en el almacenamiento en bloque de AWS (EBS).

---

### Caso 4: Prueba de Estres y Autoescalado Horizontal (HPA)

**Objetivo:** Demostrar que Kubernetes escala dinamicamente la cantidad de replicas al superar el umbral de procesamiento asignado.

**Secuencia de prueba:**
1. En una primera terminal, monitorizar el autoescalador en tiempo real:
   ```powershell
   kubectl get hpa backend-hpa -n usn -w
   ```
2. En una segunda terminal, iniciar la ejecucion del contenedor generador de carga:
   ```powershell
   kubectl apply -f k8s/08-stress-job.yaml
   ```

**Resultado esperado:**
- La utilizacion de CPU del Backend supera el umbral configurado del 50%.
- El controlador HPA emite una orden de escalamiento hacia el ReplicaSet, incrementando la dotacion de pods de 3 a 6 replicas.
- Tras concluir el periodo de carga, Kubernetes ejecuta el proceso de reduccion gradual (scale-down) para optimizar el consumo de recursos.

---

### Caso 5: Validacion del Microservicio de Inteligencia Artificial

**Objetivo:** Verificar la integracion del microservicio de procesamiento de lenguaje natural en los flujos de moderacion de publicaciones.

**Secuencia de prueba:**
1. En la caja de publicacion de la red social, ingresar un texto con terminos ofensivos (ejemplo: *"odio al mundo"*).
   - **Resultado:** La interfaz muestra una etiqueta de advertencia roja `Rechazado por IA`. Al pulsar el boton de compartir, el envio se bloquea y se emite una notificacion de moderacion impidiendo el registro en la base de datos.
2. Ingresar una oracion con contenido favorable (ejemplo: *"Excelente proyecto desplegado en la nube de AWS"*).
   - **Resultado:** La interfaz valida el mensaje con una etiqueta verde `Aprobado por IA (Sentimiento POSITIVE)` y procesa la publicacion con exito.
3. Consultar las metricas del servicio de IA desde el navegador accediendo a la ruta `/stats`:
   ```powershell
   curl http://<ip-del-servicio>:8000/stats
   ```

---

### Caso 6: Actualizaciones sin Tiempo de Inactividad (Rolling Update)

**Objetivo:** Demostrar la actualizacion de version de un microservicio sin desconectar a los usuarios activos.

**Comando de ejecucion:**
```powershell
kubectl rollout status deployment/backend-deployment -n usn
```

**Explicacion tecnica:**
La politica `RollingUpdate` utiliza los parametros `maxSurge: 1` y `maxUnavailable: 0`. Esto obliga a Kubernetes a levantar un pod nuevo y validar sus pruebas de salud (`Readiness Probe`) antes de proceder a la terminacion del pod anterior, asegurando disponibilidad continua.

---

## 8. Ejecucion Local para Desarrollo (Docker Compose)

Para reproducir localmente la arquitectura completa antes del despliegue en la nube:

```powershell
docker-compose up -d --build
```

### Puertos y Puntos de Enlace Locales:
- **Frontend Web:** [http://localhost:3000](http://localhost:3000)
- **Backend Core API:** [http://localhost:5000](http://localhost:5000)
- **Servidor Socket:** [http://localhost:8800](http://localhost:8800)
- **Microservicio de IA:** [http://localhost:8000](http://localhost:8000) (Documentacion OpenAPI en `/docs`)
- **Base de Datos MySQL:** `localhost:3307` (Base de datos: `railway`, Usuario: `root`, Clave: `admin`)

Para finalizar la ejecucion local:
```powershell
docker-compose down
```

---

## 9. Fase 5: Eliminacion de Recursos en AWS

Al concluir la presentacion o laboratorio, eliminar los recursos aprovisionados para evitar consumo indebido de creditos:

### Si se utilizo Amazon EKS:
```powershell
eksctl delete cluster --name usn-cluster --region us-east-1
```

### Si se utilizo una instancia EC2:
Detener o terminar la instancia directamente desde el panel de administracion de Amazon EC2 en la consola web de AWS.
