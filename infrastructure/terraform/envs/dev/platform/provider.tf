provider "aws" {
  region = var.aws_region

  # Usa la cadena de credenciales de AWS (aws login, AWS_PROFILE); sin claves aquí.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = "usn"
      Environment = var.environment
      Layer       = "platform"
      ManagedBy   = "Terraform"
    }
  }
}

# Acceso a la API de Kubernetes del cluster recién creado, con un token
# temporal de IAM (la misma identidad que ejecuta Terraform).
provider "kubernetes" {
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name, "--region", var.aws_region]
  }
}
