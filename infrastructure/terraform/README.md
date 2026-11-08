# Infraestructura AWS de USN (Terraform)

Define de forma reproducible toda la plataforma AWS sobre la que corre la
aplicación: red, cluster EKS, base de datos RDS, registro de imágenes, permisos
para CI/CD, métricas para el autoscaling, monitoreo y control de costos. No
despliega la aplicación: eso lo hacen los manifiestos Kubernetes mediante el
pipeline de CD.

## Arquitectura

```text
                    GitHub Actions ──access key──► IAM user usn-cluster-github-cd
                               │                      │ push        │ kubectl (solo ns "usn")
                               ▼                      ▼             ▼
┌──────────────────────────── VPC 10.0.0.0/16 (2 AZs) ─────────────────────────────┐
│  Subnets públicas: NAT Gateway, balanceadores          ECR: usn-backend, usn-frontend,
│  Subnets privadas: workers EKS (sin IP pública)             usn-socket, usn-ai-service
│  RDS MySQL 8.0 (db.t3.micro, subnets privadas, solo accesible desde EKS)          │
│                                                                                   │
│  EKS usn-cluster (K8s 1.35)                                                       │
│   ├─ Managed Node Group c7i-flex.large (2–4 nodos)                                │
│   ├─ Add-ons: vpc-cni, kube-proxy, coredns, eks-pod-identity-agent                │
│   ├─ aws-ebs-csi-driver      → volúmenes EBS para PVCs (Pod Identity)             │
│   ├─ metrics-server          → métricas CPU/memoria para el HPA                   │
│   └─ amazon-cloudwatch-observability → Container Insights + Fluent Bit (Pod Id.)  │
└───────────────────────────────────────────────────────────────────────────────────┘
CloudWatch: logs del control plane y de contenedores (7 días), dashboard, alarmas.
Secrets Manager: credenciales de la BD.   Budgets: presupuesto mensual con alertas.
S3: estado remoto de Terraform.
```

## Estructura

Cada componente de la arquitectura es un **módulo** con sus entradas
(`variables.tf`) y salidas (`outputs.tf`). El ambiente `envs/dev` los compone
en **dos capas** con estados separados, según su ciclo de vida y su costo:

| Capa | Contenido | Ciclo de vida | Costo |
| --- | --- | --- | --- |
| `envs/dev/base` | ECR, identidad de GitHub Actions, presupuesto | Se crea **una vez** y se conserva | ~0 USD |
| `envs/dev/platform` | Red y NAT, EKS y nodos, RDS, monitoreo, namespace `usn` | Se **crea y destruye** en cada sesión | ~0.35 USD/h |

```text
infrastructure/terraform/
├── bootstrap/            Bucket S3 del estado remoto (una vez por cuenta)
├── envs/
│   └── dev/
│       ├── base/         Capa permanente: registry, cicd, budget
│       └── platform/     Capa temporal: network, cluster, database, observability
│                         (lee la identidad del pipeline del estado de base)
├── modules/
│   ├── network/          VPC, subnets públicas/privadas, NAT Gateway
│   ├── cluster/          EKS, node group, add-ons y acceso del pipeline al namespace
│   ├── database/         RDS MySQL, security group, contraseña y Secrets Manager
│   ├── observability/    Dashboard, alarmas y SNS
│   ├── registry/         Repositorios ECR
│   ├── cicd/             Identidad de GitHub Actions (usuario IAM u OIDC)
│   └── budget/           Presupuesto mensual
└── .tflint.hcl           Reglas de análisis estático
```

Cada capa tiene `main.tf` (compone los módulos), `variables.tf`,
`terraform.tfvars` (valores sin secretos), `outputs.tf`, `provider.tf`,
`backend.tf` (su archivo de estado en S3) y `versions.tf`.

**Dependencias entre módulos:**

| Módulo | Capa | Recibe de | Entrega a |
| --- | --- | --- | --- |
| `registry` | base | — | ARNs de repositorios → `cicd` |
| `cicd` | base | `registry` | Identidad del pipeline → `cluster` (vía estado remoto) |
| `budget` | base | — | — |
| `network` | platform | — | VPC y subnets → `cluster`, `database` |
| `cluster` | platform | `network`, identidad de `cicd` | security group → `database`; nombre → `observability` |
| `database` | platform | `network`, `cluster` | identificador → `observability` |
| `observability` | platform | `cluster`, `database` | URL del dashboard |

Los permisos del pipeline (módulo `cicd`) se definen sobre los **nombres fijos**
del cluster (`usn-cluster`) y del secreto (`usn-cluster/dev/mysql`), así que
siguen siendo válidos cada vez que la capa platform se recrea.

Para agregar otro ambiente (por ejemplo `envs/prod`) se copian las dos capas y
se cambian `terraform.tfvars` y la `key` de cada `backend.tf`. Los módulos no se tocan.

## Decisiones de diseño

- **Módulos por componente**: la estructura del código coincide con la
  arquitectura. Cada módulo se entiende y se revisa por separado y se puede
  reutilizar en otros ambientes.
- **Dos capas con estados separados**: lo que cobra por hora (EKS, nodos, NAT,
  RDS) se destruye al terminar cada sesión sin afectar lo permanente. Las
  imágenes de ECR se conservan y la clave de GitHub Actions no cambia, así que
  recrear el entorno no requiere pasos manuales. El namespace `usn` lo crea
  Terraform, y el Secret de la base lo crea el pipeline de CD.
- **Workers privados y NAT único**: los nodos no tienen IP pública. Un solo NAT
  reduce el costo fijo a cambio de no tener salida redundante entre AZs, lo que
  es aceptable en un entorno académico.
- **Pod Identity en vez de claves**: EBS CSI y el agente de CloudWatch obtienen
  credenciales temporales. Su confianza está limitada a la cuenta, al cluster
  y a una ServiceAccount concreta.
- **Región us-east-2 (Ohio)**: la cuenta es un proyecto del plan gratuito de la
  nueva experiencia de AWS, y su organización solo permite operar en us-east-2
  (política SCP). En las demás regiones las APIs de EC2, EKS, RDS y ECR
  devuelven *explicit deny*.
- **Workers c7i-flex.large**: el plan gratuito solo permite lanzar tipos de
  instancia *free tier* (`RunInstances` falla con "not eligible for Free Tier").
  `c7i-flex.large` (2 vCPU, 4 GiB) es el tipo permitido equivalente a un
  t3.medium. Los tipos micro y small no tienen memoria suficiente para Spring
  Boot y los add-ons.
- **Usuario IAM dedicado para GitHub Actions**: lo ideal es OIDC, sin claves de
  larga duración, pero la SCP de la organización bloquea los proveedores OIDC
  de IAM. Por eso el módulo `cicd` crea un usuario `usn-cluster-github-cd` con
  permisos mínimos: subir imágenes a los repos del proyecto, obtener el
  kubeconfig y leer el secreto de la base. Dentro de Kubernetes solo administra
  el namespace `usn` (`AmazonEKSAdminPolicy` con alcance de namespace). Su
  access key se crea fuera de Terraform, para que no quede en el estado, y se
  guarda solo como GitHub Secret cifrado. En una cuenta que permita OIDC basta
  con `github_auth_mode = "oidc"`.
- **Sin IRSA**: los add-ons usan Pod Identity, así que el cluster no crea
  proveedor OIDC (`enable_irsa = false`).
- **Amazon RDS en vez de MySQL dentro de Kubernetes**: la base de datos es un
  servicio gestionado con backups automáticos, parches, cifrado y métricas
  propias. Su ciclo de vida es independiente del cluster, así que se pueden
  recrear los pods o los nodos sin riesgo para los datos. El backend queda sin
  estado, que es lo que permite escalarlo con el HPA. La instancia no es pública:
  solo acepta conexiones al puerto 3306 desde el security group del cluster.
- **Credenciales sin intervención manual**: Terraform genera la contraseña y la
  guarda en Secrets Manager junto con el endpoint. El pipeline de CD la lee con
  sus credenciales de pipeline y crea el Secret de Kubernetes, así que no aparece en el
  repositorio ni en GitHub.
- **ECR con tags inmutables**: cada imagen se publica con el SHA del commit, así
  que una versión desplegada no se puede sobrescribir y siempre se rastrea
  hasta su código. La lifecycle policy conserva las últimas 15 imágenes.
- **metrics-server como add-on de EKS**: es el requisito para que el HPA lea
  la utilización de CPU y memoria.
- **Container Insights (CloudWatch)**: se eligió frente a Prometheus/Grafana
  porque es el servicio de referencia del curso, no requiere operar más
  componentes en el cluster y entrega métricas y logs centralizados. Los log
  groups se crean con retención de 7 días para controlar el costo.
- **Endpoint público de EKS**: los runners hospedados de GitHub usan IPs
  variables, así que el endpoint queda abierto pero protegido por IAM y access
  entries. Se puede restringir con `cluster_endpoint_public_access_cidrs`.

## Requisitos

- Terraform `>= 1.12, < 2` (probado con 1.17.1), AWS CLI v2 y `jq`.
- `kubectl` compatible con EKS 1.35 (±1 versión menor).
- Credenciales de una identidad IAM con permisos de administración sobre la
  cuenta `055147668929`, usando la cadena estándar de AWS (`AWS_PROFILE`,
  `aws sso login`, variables de entorno). **No guardar claves en archivos.**
- Una cuenta AWS normal o del plan gratuito, en la región us-east-2. AWS Academy
  Learner Lab no sirve: no permite crear roles IAM, y esta configuración los
  necesita para Pod Identity.
- Sesión iniciada con `aws login` (verificar con `aws sts get-caller-identity`).

## 1. Preparación (una sola vez)

### 1.1 Bucket de estado

```bash
cd infrastructure/terraform/bootstrap
terraform init
terraform apply
```

### 1.2 Capa base

```bash
cd ../envs/dev/base
terraform init
terraform apply
```

Crea los repositorios ECR, el usuario IAM `usn-cluster-github-cd` y el
presupuesto. No genera costo por hora.

### 1.3 Conectar GitHub Actions

Crear la access key del usuario del pipeline y copiarla **directo a GitHub**.
No guardarla en archivos, en el repositorio ni en chats:

```bash
aws iam create-access-key --user-name "$(terraform output -raw github_cd_user_name)"
```

En GitHub → *Settings → Secrets and variables → Actions*:

| Tipo | Nombre | Valor |
| --- | --- | --- |
| Secret | `AWS_ACCESS_KEY_ID` | `AccessKeyId` del comando anterior |
| Secret | `AWS_SECRET_ACCESS_KEY` | `SecretAccessKey` del comando anterior |
| Variable | `AWS_REGION` | `us-east-2` |
| Variable | `EKS_CLUSTER_NAME` | `usn-cluster` |
| Variable | `ECR_REGISTRY` | `terraform output -raw ecr_registry` |
| Variable | `DB_SECRET_ID` | `usn-cluster/dev/mysql` |
| Variable | `K8S_NAMESPACE` | `usn` |

Como la capa base no se destruye, **esto se hace una sola vez**.

**Rotación**: si la clave se expone, eliminarla con
`aws iam delete-access-key --user-name usn-cluster-github-cd --access-key-id <id>`,
crear otra y actualizar los dos Secrets.

**Casos especiales:**

- *Con `github_auth_mode = "oidc"` y el proveedor OIDC de GitHub ya creado en la
  cuenta*: usar `create_github_oidc_provider = false`.
- *Repositorios ECR creados a mano*: importarlos antes del apply de base, uno
  por repositorio, con
  `terraform import 'module.registry.aws_ecr_repository.app["usn-backend"]' usn-backend`.

## 2. Sesión de trabajo: crear y destruir la capa platform

### 2.1 Crear (unos 20 minutos; desde aquí se cobra)

```bash
cd infrastructure/terraform/envs/dev/platform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Crea red, NAT, EKS con sus nodos y add-ons, RDS, el monitoreo y el namespace
`usn`, y da acceso al pipeline dentro de ese namespace. Después:

```bash
aws eks update-kubeconfig --region us-east-2 --name usn-cluster
kubectl get nodes                        # 2 nodos Ready
kubectl get pods -n kube-system          # metrics-server, ebs-csi, coredns
kubectl get pods -n amazon-cloudwatch    # cloudwatch-agent, fluent-bit
kubectl top nodes                        # confirma que metrics-server funciona
```

Para probar la conexión del pipeline: GitHub → *Actions → AWS connection check
→ Run workflow*.

### 2.2 Conexión del backend con RDS

La aplicación no necesita el StatefulSet de MySQL, su PVC ni la StorageClass.
El backend recibe la conexión desde el Secret `db-credentials`
(`envFrom: [{secretRef: {name: db-credentials}}]`), con las claves
`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` y
`SPRING_DATASOURCE_PASSWORD`. Lo crea el **pipeline de CD** en cada despliegue
leyendo Secrets Manager. Para crearlo a mano (PowerShell):

```powershell
$db = aws secretsmanager get-secret-value --secret-id usn-cluster/dev/mysql --query SecretString --output text | ConvertFrom-Json
kubectl -n usn create secret generic db-credentials --from-literal=SPRING_DATASOURCE_URL="$($db.jdbc_url)" --from-literal=SPRING_DATASOURCE_USERNAME="$($db.username)" --from-literal=SPRING_DATASOURCE_PASSWORD="$($db.password)"
Remove-Variable db
```

La base `railway` la crea RDS vacía; las tablas las genera Hibernate
(`ddl-auto: update`) al iniciar el backend. Para conectarse manualmente:

```bash
kubectl -n usn run mysql-client --rm -it --image=mysql:8.0 --restart=Never -- \
  mysql -h "$(terraform output -raw db_endpoint)" -u usn -p railway
```

### 2.3 Destruir al terminar (unos 15 minutos)

```bash
cd infrastructure/terraform/envs/dev/platform
terraform destroy
```

Terraform elimina primero el namespace `usn`. Kubernetes borra sus Services y,
con ellos, los balanceadores de carga antes de que se elimine la VPC.
Comprobar después que no quedó nada cobrando:

```bash
aws eks list-clusters --region us-east-2
aws ec2 describe-nat-gateways --region us-east-2 --filter Name=state,Values=available
aws elbv2 describe-load-balancers --region us-east-2 --query "LoadBalancers[].LoadBalancerName"
aws elb describe-load-balancers --region us-east-2 --query "LoadBalancerDescriptions[].LoadBalancerName"
aws ec2 describe-volumes --region us-east-2 --query "Volumes[].VolumeId"
```

**La base de datos RDS se elimina junto con sus datos**
(`db_skip_final_snapshot = true`). Para conservarlos, poner
`db_skip_final_snapshot = false` antes del destroy. Terraform crea entonces el
snapshot `usn-cluster-mysql-final`, que cobra almacenamiento hasta que se borra.

## 3. Actualizar y cerrar

**Actualizar:** cambiar el código de un módulo o los parámetros
(`terraform.tfvars` de la capa) en una rama y abrir un Pull Request. El
workflow **Terraform CI** ejecuta `fmt` y `tflint` sobre todo el código,
`validate` sobre `base`, `platform` y `bootstrap`, y `checkov`, cuyo reporte
se publica. Después del merge: `terraform plan -out=tfplan` y
`terraform apply tfplan` en la capa correspondiente.

Ejemplos de parámetros: `node_instance_types`, `node_min_size`/`node_max_size`,
`kubernetes_version`, `db_instance_class` y `alert_emails` (platform);
`monthly_budget_usd` y `ecr_keep_last_images` (base).

**Cerrar el proyecto** (al terminar el curso), en este orden:

```bash
cd infrastructure/terraform/envs/dev/platform && terraform destroy   # si existe
cd ../base && terraform destroy                                      # ECR, usuario IAM, presupuesto
cd ../../../bootstrap && terraform destroy                           # bucket de estado
```

## 4. Costos y control de consumo

Mientras el entorno existe, generan costo: control plane de EKS, 2 × c7i-flex.large,
discos EBS, RDS db.t3.micro con 20 GiB gp3 y su backup, Secrets Manager (un
secreto), NAT Gateway y su IPv4 pública, balanceadores creados por
Kubernetes, CloudWatch (métricas de Container Insights y logs), KMS y tráfico.
El NAT, el control plane y RDS cobran aunque no haya aplicaciones desplegadas.

- El módulo `budget` (capa base) crea un presupuesto mensual
  (`monthly_budget_usd`, 100 USD). Con `alert_emails` se avisa al
  50 %, 80 % y 100 % del gasto real y al 100 % del pronosticado.
- Revisar el consumo en *Billing → Cost Explorer* filtrando por la etiqueta
  `Project = usn` (todas las etiquetas se aplican mediante `default_tags`).
- **Destruir la capa platform (sección 2.3) cuando no se esté usando.** La
  capa base cuesta centavos al mes (almacenamiento de imágenes en ECR).

Referencias: [precios EKS](https://aws.amazon.com/eks/pricing/),
[EC2](https://aws.amazon.com/ec2/pricing/on-demand/),
[VPC/NAT](https://aws.amazon.com/vpc/pricing/),
[RDS](https://aws.amazon.com/rds/mysql/pricing/),
[CloudWatch](https://aws.amazon.com/cloudwatch/pricing/).

## 5. Monitoreo

- `terraform output cloudwatch_dashboard_url`: dashboard con CPU y memoria de
  nodos y workloads, número de pods, reinicios de contenedores (evidencia de
  recuperación ante fallos), tráfico, métricas de RDS y errores recientes de
  los logs.
- Logs de contenedores: log group `/aws/containerinsights/usn-cluster/application`
  (consultarlo con CloudWatch Logs Insights).
- RDS: CPU, conexiones, latencia e IOPS. Logs `error` y `slowquery` en
  `/aws/rds/instance/usn-cluster-mysql/*`.
- Alarmas (5 minutos sostenidos): CPU de nodos sobre 80 %, memoria de nodos
  sobre 85 % y CPU de RDS sobre 80 %. También hay una alarma si RDS tiene menos
  de 2 GiB libres. Si `alert_emails` está definido, se notifican por SNS (hay
  que confirmar la suscripción desde el correo).
- Desde la terminal: `kubectl top pods -n usn` y `kubectl get hpa -n usn -w`.

## Referencias

- [Módulo EKS 21.26.0](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/21.26.0) ·
  [Módulo VPC 6.7.3](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/6.7.3)
- [Estructura de módulos de Terraform](https://developer.hashicorp.com/terraform/language/modules/develop/structure) ·
  [bloques moved](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
- [EBS CSI en EKS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) ·
  [Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Container Insights en EKS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Observability-EKS-addon.html)
- [GitHub Actions OIDC en AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Amazon RDS for MySQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html)
- [Access entries de EKS](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [Backend S3 de Terraform](https://developer.hashicorp.com/terraform/language/backend/s3)
