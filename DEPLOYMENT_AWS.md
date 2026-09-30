# Guia de Despliegue Automatizado en AWS y Kubernetes (IaC)

Este documento detalla el procedimiento tecnico para aprovisionar la infraestructura en Amazon Web Services (AWS) mediante Infraestructura como Codigo (IaC) y desplegar la arquitectura completa de microservicios sobre Kubernetes sin necesidad de realizar configuraciones manuales en consolas web.

---

## Tabla de Contenidos
1. [Requisitos Previos](#1-requisitos-previos)
2. [Paso 1: Aprovisionamiento Automatizado de la Infraestructura en AWS](#paso-1-aprovisionamiento-automatizado-de-la-infraestructura-en-aws)
   - [Metodo 1: Mediante AWS CLI (Recomendado)](#metodo-1-mediante-aws-cli-recomendado)
   - [Metodo 2: Mediante la Consola Web de CloudFormation](#metodo-2-mediante-la-consola-web-de-cloudformation)
3. [Paso 2: Compilacion y Publicacion de Imagenes en Docker Hub](#paso-2-compilacion-y-publicacion-de-imagenes-en-docker-hub)
4. [Paso 3: Despliegue de los Manifiestos de Kubernetes en AWS](#paso-3-despliegue-de-los-manifiestos-de-kubernetes-en-aws)
5. [Paso 4: Verificacion del Estado de los Contenedores](#paso-4-verificacion-del-estado-de-los-contenedores)
6. [Paso 5: Protocolo de Demostracion para Evaluacion Docente](#paso-5-protocolo-de-demostracion-para-evaluacion-docente)
   - [Prueba 1: Distribucion y Alta Disponibilidad de Replicas](#prueba-1-distribucion-y-alta-disponibilidad-de-replicas)
   - [Prueba 2: Tolerancia a Fallos y Autocuracion (Self-Healing)](#prueba-2-tolerancia-a-fallos-y-autocuracion-self-healing)
   - [Prueba 3: Persistencia de Datos tras Destruccion de Base de Datos](#prueba-3-persistencia-de-datos-tras-destruccion-de-base-de-datos)
   - [Prueba 4: Prueba de Carga y Autoescalado Horizontal (HPA)](#prueba-4-prueba-de-carga-y-autoescalado-horizontal-hpa)
   - [Prueba 5: Filtro y Moderacion con el Microservicio de IA](#prueba-5-filtro-y-moderacion-con-el-microservicio-de-ia)
7. [Paso 6: Eliminacion de Recursos y Control de Costos](#paso-6-eliminacion-de-recursos-y-control-de-costos)

---

## 1. Requisitos Previos

Asegurarse de contar con las siguientes herramientas instaladas en la estacion de trabajo local:
- **AWS CLI v2:** Configurado con credenciales validas (`aws configure`).
- **Docker Desktop:** Activo para la construccion de imagenes de contenedor.
- **Git:** Para el control de versiones y envio de codigo al repositorio.

---

## Paso 1: Aprovisionamiento Automatizado de la Infraestructura en AWS

El repositorio incluye la plantilla declarativa `aws/ec2-k8s-template.yaml`. Este archivo de CloudFormation automatiza:
- La creacion del Grupo de Seguridad con los puertos autorizados: `80`, `3000`, `5000`, `8000`, `8800` y `6443`.
- El aprovisionamiento de una maquina virtual EC2 tipo `t3.medium` con disco en bloque elástico de 25 GiB.
- La ejecucion de un script `UserData` que instala y deja operativo Kubernetes (distribucion ligera oficial k3s) de forma autonoma.

### Metodo 1: Mediante AWS CLI (Recomendado)

Ejecutar desde PowerShell en la raiz del proyecto:

```powershell
# 1. Crear la infraestructura mediante la plantilla de CloudFormation
aws cloudformation create-stack `
  --stack-name usn-k8s-stack `
  --template-body file://aws/ec2-k8s-template.yaml `
  --parameters ParameterKey=InstanceType,ParameterValue=t3.medium `
  --region us-east-1

# 2. Esperar a que AWS complete la creacion (demora aproximadamente 60 segundos)
aws cloudformation wait stack-create-complete `
  --stack-name usn-k8s-stack `
  --region us-east-1

# 3. Obtener la direccion IP publica generada por AWS
aws cloudformation describe-stacks `
  --stack-name usn-k8s-stack `
  --region us-east-1 `
  --query "Stacks[0].Outputs" `
  --output table
```

### Metodo 2: Mediante la Consola Web de CloudFormation

1. Iniciar sesion en la consola de AWS y acceder al servicio **CloudFormation**.
2. Hacer clic en **Create stack** (Crear pila) > **With new resources (standard)**.
3. En la seccion *Template source*, seleccionar **Upload a template file** y subir el archivo local `aws/ec2-k8s-template.yaml`.
4. Asignar como nombre de la pila: `usn-k8s-stack`.
5. Avanzar con los valores predeterminados y hacer clic en **Submit**.
6. En la pestaña **Outputs** (Salidas), se mostraran las URLs e IP publica asignadas.

---

## Paso 2: Compilacion y Publicacion de Imagenes en Docker Hub

Para que los nodos en AWS descarguen las aplicaciones, compilar y publicar las imagenes de contenedor:

```powershell
# 1. Iniciar sesion en el registro Docker Hub
docker login

# 2. Compilar y publicar Backend (Java 17 / Spring Boot)
docker build -t teriyaki08/usn-backend:latest ./backend
docker push teriyaki08/usn-backend:latest

# 3. Compilar y publicar Frontend (React 18)
docker build -t teriyaki08/usn-frontend:latest ./client
docker push teriyaki08/usn-frontend:latest

# 4. Compilar y publicar Servidor Socket (Node.js / WebSockets)
docker build -t teriyaki08/usn-socket:latest ./socket
docker push teriyaki08/usn-socket:latest

# 5. Compilar y publicar Microservicio de IA (Python / FastAPI)
docker build -t teriyaki08/usn-ai-service:latest ./ai-service
docker push teriyaki08/usn-ai-service:latest
```

---

## Paso 3: Despliegue de los Manifiestos de Kubernetes en AWS

1. Conectarse a la instancia EC2 por SSH utilizando la IP publica obtenida en el Paso 1:
   ```bash
   ssh ubuntu@<DIRECCION_IP_PUBLICA>
   ```

2. Clonar el repositorio con los archivos de Kubernetes:
   ```bash
   git clone -b feature/import-application https://github.com/ancelcruzch/usn-aws-deployment.git
   cd usn-aws-deployment
   ```

3. Aplicar todos los manifiestos declarativos:
   ```bash
   kubectl apply -f k8s/
   ```

---

## Paso 4: Verificacion del Estado de los Contenedores

Ejecutar dentro de la instancia para confirmar el levantamiento de todos los servicios:

```bash
# 1. Verificar que los 10 pods se encuentren en estado 'Running'
kubectl get pods -n usn

# 2. Consultar los servicios de red expuestos
kubectl get services -n usn
```

### URLs de Acceso Publico:
- **Frontend Web de la Red Social:** `http://<DIRECCION_IP_PUBLICA>:3000`
- **Panel Interactivo de la Inteligencia Artificial:** `http://<DIRECCION_IP_PUBLICA>:8000/docs`
- **Backend API REST:** `http://<DIRECCION_IP_PUBLICA>:5000`
- **Servidor de WebSockets:** `http://<DIRECCION_IP_PUBLICA>:8800`

---

## Paso 5: Protocolo de Demostracion para Evaluacion Docente

Seguir este orden de ejecucion frente al evaluador para comprobar las caracteristicas de resiliencia y gestion en Kubernetes:

---

### Prueba 1: Distribucion y Alta Disponibilidad de Replicas

**Objetivo:** Mostrar la separacion de microservicios y su ejecucion simultanea en multiples replicas.

```bash
kubectl get pods -n usn -o wide
```

**Puntos a explicar al evaluador:**
- La aplicacion se distribuye en 4 microservicios funcionales mas 1 base de datos relacional.
- Se contabilizan 10 pods activos concurrentemente:
  - 3 replicas de Backend REST API.
  - 2 replicas de Frontend React.
  - 2 replicas de Sockets en tiempo real.
  - 2 replicas de Inteligencia Artificial para moderacion.
  - 1 pod de MySQL con volumen persistente.

---

### Prueba 2: Tolerancia a Fallos y Autocuracion (Self-Healing)

**Objetivo:** Evidenciar que la caida de un contenedor no interrumpe el servicio y activa la recuperacion automatica.

1. Mantener la aplicacion web abierta en el navegador.
2. Identificar el nombre de un pod del backend y forzar su eliminacion:
   ```bash
   kubectl delete pod $(kubectl get pods -n usn -l app=backend -o jsonpath='{.items[0].metadata.name}') -n usn
   ```
3. Ejecutar de inmediato:
   ```bash
   kubectl get pods -n usn -l app=backend
   ```

**Puntos a explicar al evaluador:**
- La experiencia de usuario no sufre caidas debido a que las 2 replicas remanentes continuaron atendiendo las solicitudes HTTP.
- El controlador de Kubernetes detecto la perdida del pod y creo un nuevo pod de reemplazo en menos de 3 segundos para restablecer la regla de 3 replicas deseadas.

---

### Prueba 3: Persistencia de Datos tras Destruccion de Base de Datos

**Objetivo:** Demostrar que los datos no se pierden ante la falla catastrofica del contenedor de base de datos gracias al volumen elástico desacoplado (PVC).

1. Ingresar a la red social y registrar un usuario o publicar un mensaje.
2. Eliminar intencionalmente el pod de MySQL:
   ```bash
   kubectl delete pod -l app=mysql -n usn
   ```
3. Aguardar a que Kubernetes regenere el pod:
   ```bash
   kubectl get pods -n usn -l app=mysql -w
   ```
4. Actualizar la pagina web en el navegador.

**Puntos a explicar al evaluador:**
- La base de datos volvio a iniciar montando el mismo `PersistentVolumeClaim`. Los usuarios y publicaciones persisten porque el almacenamiento esta disociado del ciclo de vida del contenedor.

---

### Prueba 4: Prueba de Carga y Autoescalado Horizontal (HPA)

**Objetivo:** Demostrar que el sistema escala dinamicamente agregando replicas ante un incremento en el consumo de CPU.

1. En una primera terminal, monitorear el autoescalador en vivo:
   ```bash
   kubectl get hpa backend-hpa -n usn -w
   ```
2. En una segunda terminal, iniciar la ejecucion del contenedor generador de estres:
   ```bash
   kubectl apply -f k8s/08-stress-job.yaml
   ```

**Puntos a explicar al evaluador:**
- El contenedor de estres bombardea el backend con 500 peticiones continuas.
- Al superar el 50% de uso de CPU configurado, el objeto `HorizontalPodAutoscaler` emite una instruccion de escalado hacia el ReplicaSet, elevando las replicas de 3 a 6 pods de forma automatica.

---

### Prueba 5: Filtro y Moderacion con el Microservicio de IA

**Objetivo:** Verificar la integracion del microservicio de procesamiento de lenguaje natural en los flujos de publicacion.

1. En el campo de publicacion de la red social, ingresar un texto hostil (ejemplo: *"odio al mundo"*).
   - **Resultado:** La interfaz muestra la etiqueta `Rechazado por IA`. Al pulsar el boton de compartir, el envio se bloquea inmediatamente y una alerta notifica la deteccion de terminos de toxicidad.
2. Ingresar un mensaje constructivo (ejemplo: *"Excelente aplicacion desplegada en Kubernetes"*).
   - **Resultado:** La interfaz valida el texto con la etiqueta `Aprobado por IA (Sentimiento POSITIVE)` y procesa la publicacion con exito.

---

## Paso 6: Eliminacion de Recursos y Control de Costos

Una vez concluida la evaluacion academica, destruir los recursos creados en AWS para evitar cargos innecesarios:

```powershell
aws cloudformation delete-stack --stack-name usn-k8s-stack --region us-east-1
```

Este comando eliminara de forma automatica la instancia EC2, el Grupo de Seguridad, los volumenes EBS asociados y las configuraciones de red.
