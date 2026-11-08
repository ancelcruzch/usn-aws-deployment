# Cluster EKS: control plane, Managed Node Group y add-ons de red.
# ebs-csi.tf y addons.tf agregan almacenamiento, métricas y observabilidad.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.26.0"

  name = var.cluster_name
  # 1.35 está en soporte estándar y a una versión menor de kubectl 1.34.1.
  kubernetes_version = var.kubernetes_version

  endpoint_public_access  = true
  endpoint_private_access = true
  # Acceso sujeto a autenticación IAM y autorización EKS. Los runners hospedados
  # de GitHub Actions usan IPs variables, por eso el valor por defecto es abierto.
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # Los add-ons obtienen permisos con EKS Pod Identity (ebs-csi.tf, addons.tf),
  # no con IRSA: no se necesita el proveedor OIDC del cluster. Además, la cuenta
  # del proyecto bloquea la creación de proveedores OIDC de IAM.
  enable_irsa = false

  # El acceso del rol de CI/CD al cluster se define en el módulo cicd.

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  # Evita cargos de soporte extendido: AWS actualizará el control plane al
  # terminar el soporte estándar. Revisar antes kubectl, workers y add-ons.
  upgrade_policy = {
    support_type = "STANDARD"
  }

  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # Componentes de red/DNS del cluster, no despliegues de la aplicación.
  # Los add-ons con permisos IAM propios están en ebs-csi.tf y addons.tf.
  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {
      before_compute = true
    }
    coredns = {}
  }

  eks_managed_node_groups = {
    usn-workers = {
      name = "usn-workers"
      # El módulo reemplaza creando primero: el sufijo evita colisiones de nombre.
      use_name_prefix = true

      subnet_ids     = var.subnet_ids
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      disk_size    = var.node_disk_size

      # disk_size se envía a EKS solo sin launch template personalizado.
      create_launch_template     = false
      use_custom_launch_template = false

      # Sin template personalizado, EKS asigna su security group del cluster.

      update_config = {
        max_unavailable = 1
      }
    }
  }

  tags = {
    Project     = "usn"
    Environment = var.environment
  }
}
