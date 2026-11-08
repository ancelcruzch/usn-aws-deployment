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
(`variables.tf`) y salidas (`outputs.tf`). El **ambiente** `envs/dev` los
compone y es el único lugar con provider, backend y valores concretos.

```text
infrastructure/terraform/
├── bootstrap/            Bucket S3 del estado remoto (una vez por cuenta)
├── envs/
│   └── dev/              Ambiente dev: aquí se ejecuta terraform
│       ├── main.tf           Conecta los módulos
│       ├── variables.tf      Parámetros del ambiente
│       ├── terraform.tfvars  Valores de dev (sin secretos)
│       ├── outputs.tf        Datos para kubectl, CI/CD y monitoreo
│       ├── provider.tf       Región, cuenta permitida, etiquetas
│       ├── backend.tf        Estado remoto en S3 (backend.hcl.example)
│       ├── versions.tf       Versiones de Terraform y providers
│       └── moved.tf          Migración de la estructura anterior
├── modules/
│   ├── network/          VPC, subnets públicas/privadas, NAT Gateway
│   ├── cluster/          EKS, node group, add-ons (EBS CSI, metrics-server, CloudWatch)
│   ├── database/         RDS MySQL, security group, contraseña y Secrets Manager
│   ├── registry/         Repositorios ECR
│   ├── cicd/             Identidad de GitHub Actions (usuario IAM u OIDC) y su acceso al cluster
│   └── observability/    Dashboard, alarmas, SNS y presupuesto
└── .tflint.hcl           Reglas de análisis estático
```

**Dependencias entre módulos:**

| Módulo | Recibe de | Entrega a |
| --- | --- | --- |
| `network` | — | VPC y subnets → `cluster`, `database` |
| `cluster` | `network` | security group → `database`; nombre y ARN → `cicd`, `observability` |
| `database` | `network`, `cluster` | ARN del secreto → `cicd`; identificador → `observability` |
| `registry` | — | ARNs de repositorios → `cicd` |
| `cicd` | `cluster`, `database`, `registry` | Usuario o rol del pipeline (output para GitHub) |
| `observability` | `cluster`, `database` | URL del dashboard |

Para agregar otro ambiente (por ejemplo `envs/prod`) se copia `envs/dev` y
se cambian `terraform.tfvars` y la `key` del backend. Los módulos no se tocan.

## Decisiones de diseño

- **Módulos por componente**: la estructura del código coincide con la
  arquitectura. Cada módulo se entiende y se revisa por separado y se puede
  reutilizar en otros ambientes.
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

## 1. Crear el entorno

### 1.1 Bucket de estado (una sola vez por cuenta)

```bash
cd infrastructure/terraform/bootstrap
terraform init
terraform apply
```

### 1.2 Infraestructura

```bash
cd ../envs/dev
cp backend.hcl.example backend.hcl   # ajustar bucket con el output state_bucket
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

A partir de aquí, todos los comandos `terraform` se ejecutan desde
`infrastructure/terraform/envs/dev`. La creación tarda unos 15–20 minutos.
Después se configura kubectl:

```bash
$(terraform output -raw configure_kubectl)
kubectl get nodes
kubectl get pods -n kube-system          # metrics-server, ebs-csi, coredns
kubectl get pods -n amazon-cloudwatch    # cloudwatch-agent, fluent-bit
kubectl top nodes                        # confirma que metrics-server funciona
```

**Casos especiales:**

- *Ya se había aplicado la versión anterior* (archivos en la raíz de
  `infrastructure/terraform`): el estado local está en esa carpeta. Hay que
  copiar `terraform.tfstate` a `envs/dev/` y ejecutar
  `terraform init -backend-config=backend.hcl -migrate-state`. Los bloques de
  `moved.tf` hacen que el plan muestre los recursos como **movidos**, no como
  recreados. Revisar el plan antes de aplicar.
- *Los repositorios ECR ya existen* (creados a mano): importarlos antes del apply.

  ```bash
  for r in usn-backend usn-frontend usn-socket usn-ai-service; do
    terraform import "module.registry.aws_ecr_repository.app[\"$r\"]" "$r"
  done
  ```

  Los tags existentes (`v1`, `v2`) se mantienen. La inmutabilidad solo impide
  sobrescribirlos.
- *Con `github_auth_mode = "oidc"` y el proveedor OIDC de GitHub ya creado en la
  cuenta*: usar `create_github_oidc_provider = false`.

### 1.3 Namespace de la aplicación (una vez, como administrador)

El rol de CD solo tiene permisos en el namespace `usn`. El Namespace es un
recurso de alcance cluster, así que lo crea el administrador una vez:

```bash
kubectl create namespace usn
```

### 1.4 Conexión del backend con RDS

La aplicación ya no necesita el StatefulSet de MySQL, su PVC ni la StorageClass.
El backend recibe la conexión por variables de entorno desde un Secret:

```bash
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw db_secret_name)" \
  --query SecretString --output text)

kubectl -n usn create secret generic db-credentials \
  --from-literal=SPRING_DATASOURCE_URL="$(echo "$SECRET" | jq -r .jdbc_url)" \
  --from-literal=SPRING_DATASOURCE_USERNAME="$(echo "$SECRET" | jq -r .username)" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="$(echo "$SECRET" | jq -r .password)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

El pipeline de CD ejecuta estos mismos pasos en cada despliegue. En el
Deployment del backend se usa `envFrom: [{secretRef: {name: db-credentials}}]`.
La base `railway` la crea RDS vacía; las tablas las genera Hibernate
(`ddl-auto: update`) al iniciar el backend.

Para conectarse a la base manualmente (está en subnets privadas):

```bash
kubectl -n usn run mysql-client --rm -it --image=mysql:8.0 --restart=Never -- \
  mysql -h "$(terraform output -raw db_endpoint)" -u usn -p railway
```

### 1.5 Conectar GitHub Actions

Crear la access key del usuario del pipeline (una vez) y copiarla directo a
GitHub. **No guardarla en archivos ni en el repositorio:**

```bash
aws iam create-access-key --user-name "$(terraform output -raw github_cd_user_name)"
```

En GitHub → *Settings → Secrets and variables → Actions*:

| Tipo | Nombre | Valor |
| --- | --- | --- |
| Secret | `AWS_ACCESS_KEY_ID` | `AccessKeyId` del comando anterior |
| Secret | `AWS_SECRET_ACCESS_KEY` | `SecretAccessKey` del comando anterior |
| Variable | `AWS_REGION` | `us-east-2` |
| Variable | `EKS_CLUSTER_NAME` | `terraform output -raw cluster_name` |
| Variable | `ECR_REGISTRY` | `terraform output -raw ecr_registry` |
| Variable | `DB_SECRET_ID` | `terraform output -raw db_secret_name` |

El workflow de CD usa `aws-actions/configure-aws-credentials` con
`aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}` y
`aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}`.

**Rotación**: si la clave se expone, o al terminar el curso, eliminarla con
`aws iam delete-access-key --user-name usn-cluster-github-cd --access-key-id <id>`
y crear otra. `terraform destroy` elimina el usuario y todas sus claves.

## 2. Actualizar el entorno

1. Cambiar el código de un módulo o los parámetros (`envs/dev/terraform.tfvars`)
   en una rama.
2. Abrir un Pull Request. El workflow **Terraform CI**
   (`.github/workflows/terraform-ci.yml`) ejecuta `fmt` y `tflint` sobre todo el
   código, `validate` sobre `envs/dev` y `bootstrap`, y `checkov`, cuyo reporte
   se publica.
3. Revisar el plan localmente: `terraform plan -out=tfplan`.
4. Después del merge: `terraform apply tfplan`.

Ejemplos de parámetros: `node_instance_types`, `node_min_size`/`node_max_size`,
`kubernetes_version`, `db_instance_class`, `alert_emails` y `monthly_budget_usd`.
Los cambios de `db_instance_class` reinician la base unos minutos. Al subir
`kubernetes_version` hay que revisar antes la compatibilidad de kubectl y de los
add-ons.

## 3. Destruir el entorno

Kubernetes crea balanceadores y volúmenes EBS **fuera de Terraform**. Si siguen
existiendo, `terraform destroy` falla al borrar la VPC o deja recursos cobrando.
Seguir este orden:

```bash
# 1. Eliminar la aplicación (Services LoadBalancer/Ingress, PVCs)
kubectl delete namespace usn --wait=true

# 2. Confirmar que no quedan balanceadores del cluster
aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName"
aws elb describe-load-balancers --query "LoadBalancerDescriptions[].LoadBalancerName"

# 3. Volúmenes EBS de PVCs con política Retain (si se usaron)
aws ec2 describe-volumes --filters Name=status,Values=available \
  --query "Volumes[].{id:VolumeId,size:Size,tags:Tags}"
aws ec2 delete-volume --volume-id <vol-id>      # solo si ya no se necesitan los datos

# 4. Destruir la infraestructura (desde envs/dev)
terraform destroy

# 5. Al cerrar el proyecto: eliminar el bucket de estado
cd ../../bootstrap && terraform destroy
```

Los repositorios ECR se borran aunque tengan imágenes (`force_delete`). Los log
groups, el dashboard y el secreto también se eliminan.

**La base de datos RDS se elimina junto con sus datos y backups automáticos**
(`db_skip_final_snapshot = true`). Para conservar los datos se pone
`db_skip_final_snapshot = false` antes del destroy. Terraform crea entonces el
snapshot `usn-cluster-mysql-final`, que sigue cobrando almacenamiento hasta que
se borra.

## 4. Costos y control de consumo

Mientras el entorno existe, generan costo: control plane de EKS, 2 × c7i-flex.large,
discos EBS, RDS db.t3.micro con 20 GiB gp3 y su backup, Secrets Manager (un
secreto), NAT Gateway y su IPv4 pública, balanceadores creados por
Kubernetes, CloudWatch (métricas de Container Insights y logs), KMS y tráfico.
El NAT, el control plane y RDS cobran aunque no haya aplicaciones desplegadas.

- El módulo `observability` crea un presupuesto mensual
  (`monthly_budget_usd`, por defecto 50 USD). Con `alert_emails` se avisa al
  50 %, 80 % y 100 % del gasto real y al 100 % del pronosticado.
- Revisar el consumo en *Billing → Cost Explorer* filtrando por la etiqueta
  `Project = usn` (todas las etiquetas se aplican mediante `default_tags`).
- **Destruir el entorno (sección 3) cuando no se esté usando.**

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
