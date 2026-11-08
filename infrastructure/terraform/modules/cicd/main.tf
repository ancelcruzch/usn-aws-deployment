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
#
# Este módulo pertenece a la capa base (permanente): no depende del cluster ni
# de la base de datos, que se crean y destruyen en cada sesión. Los permisos se
# definen sobre los nombres fijos de esos recursos. El acceso dentro de
# Kubernetes (access entry) lo crea la capa platform junto con el cluster.

data "aws_caller_identity" "current" {}

locals {
  use_oidc      = var.auth_mode == "oidc"
  principal_arn = local.use_oidc ? aws_iam_role.github_cd[0].arn : aws_iam_user.github_cd[0].arn

  # Permisos mínimos: push/pull en los repositorios del proyecto, lectura del
  # cluster para generar el kubeconfig y lectura del secreto de la base de
  # datos. Lo que puede hacer dentro de Kubernetes lo limita la access entry
  # (solo el namespace de la aplicación), creada en la capa platform.
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
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
      {
        Sid    = "ReadDatabaseCredentials"
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        # Secrets Manager agrega un sufijo aleatorio al ARN del secreto.
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.db_secret_name}-*"
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
