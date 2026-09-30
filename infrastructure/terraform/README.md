# Infraestructura EKS de USN (dev)

Esta configuración prepara únicamente infraestructura AWS. No despliega la
aplicación, no modifica ECR y no crea bases de datos ni almacenamiento Kubernetes.
No se ha ejecutado `terraform apply`.

## Configuración

- Cuenta permitida: `912759111826`; región: `us-east-1`.
- Terraform: `>= 1.12, < 2`; provider AWS: `>= 6.59, < 7`.
- Módulos fijados: VPC `6.7.3`, EKS `21.26.0`.
- EKS `usn-cluster`, Kubernetes `1.35`, compatible con `kubectl 1.34.1`.
- VPC `10.0.0.0/16`, dos AZs disponibles, dos subnets públicas y dos privadas.
- Un Internet Gateway, un NAT Gateway con una Elastic IP y sus rutas.
- Managed Node Group con prefijo `usn-workers`: AL2023 x86_64, `t3.small` On-Demand,
  un nodo inicial, mínimo uno, máximo dos y disco de 20 GiB por nodo.
  El nombre AWS incluye un sufijo para permitir crear el reemplazo antes de
  eliminar el grupo anterior. `managed_node_group_name` devuelve el nombre real.
- Workers sin IP pública, en subnets privadas. El NAT único está en una AZ:
  reduce costo fijo, pero no ofrece salida redundante entre AZs y puede generar
  cargos de tráfico entre AZs.
- Endpoints privado y público de EKS habilitados. El público admite
  `0.0.0.0/0`, con autenticación IAM; se puede restringir en `eks.tf` a la IP
  pública de administración.
- Roles IAM, permisos de lectura de ECR para los nodos, entrada administrativa
  para el creador, OIDC, cifrado KMS y logs de control plane con retención de 7 días.
- Add-ons de infraestructura: VPC CNI, kube-proxy, CoreDNS, EKS Pod Identity Agent
  y Amazon EBS CSI Driver. No hay manifests
  ni recursos Terraform Kubernetes/Helm para la aplicación.

Los límites 1–2 no instalan Cluster Autoscaler ni Karpenter. El grupo empieza con
un nodo; el escalado automático por demanda queda para otra etapa.

La política de soporte es `STANDARD`. Al terminar el soporte estándar AWS puede
actualizar el control plane; revisar antes las versiones de kubectl, nodos y
add-ons. Consultar el calendario vigente de EKS.

## Revisar sin crear recursos

Desde la raíz del repositorio:

```bash
terraform -chdir=infrastructure/terraform init
terraform -chdir=infrastructure/terraform fmt -check
terraform -chdir=infrastructure/terraform validate
terraform -chdir=infrastructure/terraform plan -out=tfplan
terraform -chdir=infrastructure/terraform show tfplan
```

Terraform usa la cadena estándar de autenticación AWS. Si se usa un perfil,
seleccionarlo con `AWS_PROFILE` en la terminal antes de ejecutar los comandos.
No guardar claves en archivos Terraform. El acceso administrativo se asigna a
la identidad con la que se ejecuta Terraform; es recomendable usar un usuario o
rol IAM destinado a administrar el cluster y revisar su ARN en el plan.

Tras agregar EBS CSI, `validate` finalizó correctamente y `plan` propuso
**5 altas, 0 cambios y 0 eliminaciones**. Regenerar el plan antes de desplegar:
refleja el estado de AWS al momento de ejecutarlo.

## EBS CSI y Pod Identity

`ebs-csi.tf` configura los add-ons `eks-pod-identity-agent` y
`aws-ebs-csi-driver`, seleccionando sus versiones más recientes compatibles con
la versión Kubernetes del cluster mediante la API de EKS.

El rol `usn-cluster-ebs-csi` tiene la política administrada
`AmazonEBSCSIDriverPolicyV2`. La asociación Pod Identity vincula ese rol con
`kube-system/ebs-csi-controller-sa`. Su confianza queda limitada a la cuenta,
al cluster y a ese namespace y ServiceAccount. No se usan claves estáticas ni
se añaden permisos EBS al rol de los nodos. La política existente
`AmazonEKSWorkerNodePolicy` permite al agente obtener credenciales Pod Identity.

Terraform ordena la creación del agente y los permisos antes de la asociación,
y de la asociación antes del driver. El plan añade esos cinco recursos sin
modificar VPC, subnets ni Managed Node Group.

El driver habilita el provisioner `ebs.csi.aws.com`; este cambio no crea PVCs,
StorageClasses ni volúmenes EBS. Una StorageClass y un PVC posteriores podrán
aprovisionar almacenamiento. Para volúmenes cifrados con una clave KMS propia
se requieren permisos adicionales sobre esa clave; no se añaden en esta etapa.

Referencias: [EBS CSI en EKS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html),
[confianza de Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-role.html),
[política V2](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEBSCSIDriverPolicyV2.html).

El estado es local. `.terraform/`, estados y planes están ignorados por Git;
conservar `.terraform.lock.hcl`. `terraform.tfvars` contiene solo valores no
secretos. Después de un despliegue futuro, conservar el estado para administrar
los recursos; no borrarlo.

## Costos orientativos

La configuración inicial usa un nodo `t3.small` con 20 GiB de EBS.
El costo depende de la tarifa vigente y de los créditos o beneficios de la cuenta;
seleccionar este tipo no garantiza que toda la infraestructura sea gratuita.

Además del nodo y su disco se facturan EKS, NAT Gateway, su IPv4 pública, KMS,
CloudWatch y tráfico. El NAT único sigue generando cargos aunque no haya
aplicaciones desplegadas. Consultar las tarifas actuales en las referencias.

Referencias:
- [Módulo EKS](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/21.26.0)
- [Módulo VPC](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/6.7.3)
- [Versiones EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- [Compatibilidad de kubectl](https://kubernetes.io/releases/version-skew-policy/#kubectl)
- [Precio EKS](https://aws.amazon.com/eks/pricing/)
- [Precio EC2](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Precio NAT e IPv4](https://aws.amazon.com/vpc/pricing/)
