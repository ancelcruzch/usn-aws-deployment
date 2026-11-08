# Control de consumo: presupuesto mensual de la cuenta con alertas por correo.
# Sin correos configurados el presupuesto existe igual y se puede revisar en
# AWS Billing > Budgets.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.cluster_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # La cuenta se paga con créditos: si se descontaran, el costo neto sería 0 y
  # las alertas nunca se dispararían. Se mide el consumo real de créditos.
  cost_types {
    include_credit = false
    include_refund = false
  }

  dynamic "notification" {
    for_each = length(var.alert_emails) > 0 ? [50, 80, 100] : []

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.alert_emails
    }
  }

  dynamic "notification" {
    for_each = length(var.alert_emails) > 0 ? [100] : []

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = var.alert_emails
    }
  }
}
