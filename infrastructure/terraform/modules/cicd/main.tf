# Identidad de AWS para el pipeline de GitHub Actions. Dos modos (auth_mode):
#
#  - "iam_user" (por defecto): usuario IAM dedicado al CI/CD. La cuenta del
#    proyecto (plan gratuito de la nueva experiencia AWS) bloquea los
#    proveedores OIDC de IAM mediante una SCP de la organización. La access key
#    se crea fuera de Terraform (ver README) y se guarda solo en GitHub Secrets.
#  - "oidc": rol asumido con OIDC de GitHub, sin claves de larga duración.
#    Preferible en cuentas que lo permitan.
#
# En ambos casos los permisos son los mismos y mínimos.

locals {
  use_oidc      = var.auth_mode == "oidc"
  principal_arn = local.use_oidc ? aws_iam_role.github_cd[0].arn : aws_iam_user.github_cd[0].arn

  # Permisos mínimos: push/pull en los repositorios del proyecto, lectura del
  # cluster para generar el kubeconfig y lectura del secreto de la base de
  # datos. Lo que puede hacer dentro de Kubernetes lo limita la access entry
  # (solo el namespace de la aplicación).
  cd_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Sid      = "EksKubeconfig"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = var.cluster_arn
      },
      {
        Sid      = "ReadDatabaseCredentials"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_secret_arn
      },
    ]
  })
}

################################################################################
# Modo iam_user
################################################################################

resource "aws_iam_user" "github_cd" {
  count = local.use_oidc ? 0 : 1

  name = "${var.name}-github-cd"
  path = "/ci/"

  # Permite destruir el usuario aunque tenga access keys creadas a mano.
  force_destroy = true
}

resource "aws_iam_user_policy" "github_cd" {
  count = local.use_oidc ? 0 : 1

  name   = "ecr-push-eks-describe"
  user   = aws_iam_user.github_cd[0].name
  policy = local.cd_policy
}

################################################################################
# Modo oidc
################################################################################

data "aws_caller_identity" "current" {}

locals {
  github_oidc_provider_arn = (
    local.use_oidc && var.create_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count = local.use_oidc && var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Solo puede asumirlo un workflow que corra sobre la rama de despliegue del
# repositorio indicado (no ramas de feature ni forks).
resource "aws_iam_role" "github_cd" {
  count = local.use_oidc ? 1 : 0

  name                 = "${var.name}-github-cd"
  description          = "Rol asumido por GitHub Actions para publicar imagenes en ECR y desplegar en EKS."
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/${var.deploy_branch}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_cd" {
  count = local.use_oidc ? 1 : 0

  name   = "ecr-push-eks-describe"
  role   = aws_iam_role.github_cd[0].id
  policy = local.cd_policy
}

################################################################################
# Acceso al cluster (ambos modos): AmazonEKSAdminPolicy limitada al namespace
# de la aplicación. Recursos de alcance cluster (el Namespace) los crea el admin.
################################################################################

resource "aws_eks_access_entry" "github_cd" {
  cluster_name  = var.cluster_name
  principal_arn = local.principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_cd" {
  cluster_name  = var.cluster_name
  principal_arn = aws_eks_access_entry.github_cd.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.app_namespace]
  }
}
