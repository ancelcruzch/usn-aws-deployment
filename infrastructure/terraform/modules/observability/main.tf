# Observabilidad y operación: dashboard de CloudWatch (nodos, pods, RDS y
# errores de la aplicación), alarmas y notificaciones por correo.
# Las métricas las generan Container Insights (módulo cluster) y RDS.

locals {
  ci_search = "{ContainerInsights,ClusterName,Namespace,PodName} ClusterName=\"${var.cluster_name}\" Namespace=\"${var.app_namespace}\""
}

################################################################################
# Notificaciones (opcionales): solo si se definen correos en alert_emails.
# Cada correo recibe un mensaje de confirmación de SNS que hay que aceptar.
################################################################################

resource "aws_sns_topic" "alerts" {
  count = length(var.alert_emails) > 0 ? 1 : 0

  name = "${var.cluster_name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  for_each = length(var.alert_emails) > 0 ? toset(var.alert_emails) : toset([])

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}

################################################################################
# Alarmas sobre los workers
################################################################################

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  alarm_description   = "CPU promedio de los workers sobre 80 % durante 5 minutos."
  namespace           = "ContainerInsights"
  metric_name         = "node_cpu_utilization"
  dimensions          = { ClusterName = var.cluster_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = aws_sns_topic.alerts[*].arn
  ok_actions          = aws_sns_topic.alerts[*].arn
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  alarm_description   = "Memoria promedio de los workers sobre 85 % durante 5 minutos."
  namespace           = "ContainerInsights"
  metric_name         = "node_memory_utilization"
  dimensions          = { ClusterName = var.cluster_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = aws_sns_topic.alerts[*].arn
  ok_actions          = aws_sns_topic.alerts[*].arn
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.db_identifier}-cpu-high"
  alarm_description   = "CPU de RDS MySQL sobre 80 % durante 5 minutos."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = aws_sns_topic.alerts[*].arn
  ok_actions          = aws_sns_topic.alerts[*].arn
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.db_identifier}-storage-low"
  alarm_description   = "Menos de 2 GiB libres en RDS MySQL."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = aws_sns_topic.alerts[*].arn
  ok_actions          = aws_sns_topic.alerts[*].arn
}

################################################################################
# Dashboard: estado de nodos y pods, consumo durante pruebas de carga y errores.
################################################################################

resource "aws_cloudwatch_dashboard" "cluster" {
  dashboard_name = "${var.cluster_name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Nodos: CPU y memoria (%)"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name, { label = "CPU" }],
            [".", "node_memory_utilization", ".", ".", { label = "Memoria" }],
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 6, height = 6
        properties = {
          title  = "Nodos activos"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["ContainerInsights", "cluster_node_count", "ClusterName", var.cluster_name, { label = "Nodos" }],
            [".", "cluster_failed_node_count", ".", ".", { label = "Nodos con fallas" }],
          ]
        }
      },
      {
        type = "metric", x = 18, y = 0, width = 6, height = 6
        properties = {
          title  = "Pods en ejecución (${var.app_namespace})"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["ContainerInsights", "namespace_number_of_running_pods", "ClusterName", var.cluster_name, "Namespace", var.app_namespace, { label = "Pods" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "CPU por workload (% de la capacidad del nodo)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            [{ expression = "SEARCH('${local.ci_search} MetricName=\"pod_cpu_utilization\"', 'Average', 60)", id = "cpu", label = "" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Memoria por workload (%)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            [{ expression = "SEARCH('${local.ci_search} MetricName=\"pod_memory_utilization\"', 'Average', 60)", id = "mem", label = "" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "Reinicios de contenedores (recuperación ante fallos)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            [{ expression = "SEARCH('${local.ci_search} MetricName=\"pod_number_of_container_restarts\"', 'Maximum', 60)", id = "restarts", label = "" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Tráfico de red por workload (bytes/s)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            [{ expression = "SEARCH('${local.ci_search} MetricName=\"pod_network_rx_bytes\"', 'Average', 60)", id = "rx", label = "" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 18, width = 12, height = 6
        properties = {
          title  = "RDS MySQL: CPU (%) y conexiones"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_identifier, { label = "CPU %" }],
            [".", "DatabaseConnections", ".", ".", { label = "Conexiones", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 18, width = 12, height = 6
        properties = {
          title  = "RDS MySQL: latencia (s) e IOPS"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.db_identifier, { label = "Latencia lectura" }],
            [".", "WriteLatency", ".", ".", { label = "Latencia escritura" }],
            [".", "ReadIOPS", ".", ".", { label = "IOPS lectura", yAxis = "right" }],
            [".", "WriteIOPS", ".", ".", { label = "IOPS escritura", yAxis = "right" }],
          ]
        }
      },
      {
        type = "log", x = 0, y = 24, width = 24, height = 8
        properties = {
          title  = "Errores recientes en ${var.app_namespace}"
          region = var.aws_region
          view   = "table"
          query  = <<-EOT
            SOURCE '${var.application_log_group}'
            | fields @timestamp, kubernetes.pod_name, log
            | filter kubernetes.namespace_name = '${var.app_namespace}'
            | filter log like /(?i)(error|exception|fatal)/
            | sort @timestamp desc
            | limit 50
          EOT
        }
      },
    ]
  })
}
