################################################################################
# metrics-server: expone CPU/memoria de pods a la API de métricas de Kubernetes.
# Sin él, el Horizontal Pod Autoscaler no puede calcular la utilización.
################################################################################

data "aws_eks_addon_version" "metrics_server" {
  addon_name         = "metrics-server"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "metrics-server"
  addon_version = data.aws_eks_addon_version.metrics_server.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
}

################################################################################
# Amazon CloudWatch Observability: Container Insights (métricas de nodos, pods
# y servicios) y Fluent Bit (logs de contenedores hacia CloudWatch Logs).
################################################################################

locals {
  container_insights_log_groups = ["application", "dataplane", "host", "performance"]
}

# Se crean antes que el add-on para fijar la retención; si el agente los creara,
# los logs se conservarían indefinidamente y generarían costo.
resource "aws_cloudwatch_log_group" "container_insights" {
  for_each = toset(local.container_insights_log_groups)

  name              = "/aws/containerinsights/${var.cluster_name}/${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "cloudwatch_observability" {
  name = "${var.cluster_name}-cloudwatch-observability"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "aws:SourceAccount"                         = data.aws_caller_identity.current.account_id
          "aws:RequestTag/kubernetes-namespace"       = "amazon-cloudwatch"
          "aws:RequestTag/kubernetes-service-account" = "cloudwatch-agent"
        }
        ArnEquals = {
          "aws:SourceArn" = module.eks.cluster_arn
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_eks_addon_version" "cloudwatch_observability" {
  addon_name         = "amazon-cloudwatch-observability"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = data.aws_eks_addon_version.cloudwatch_observability.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  pod_identity_association {
    role_arn        = aws_iam_role.cloudwatch_observability.arn
    service_account = "cloudwatch-agent"
  }

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.cloudwatch_observability,
    aws_cloudwatch_log_group.container_insights,
  ]
}
