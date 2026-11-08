output "dashboard_url" {
  description = "URL del dashboard de CloudWatch."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.cluster.dashboard_name}"
}

output "alerts_topic_arn" {
  description = "Tópico SNS de alertas (null si no hay correos configurados)."
  value       = one(aws_sns_topic.alerts[*].arn)
}
