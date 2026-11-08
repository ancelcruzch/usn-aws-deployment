variable "name" {
  description = "Prefijo del nombre del presupuesto."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Presupuesto mensual en USD."
  type        = number
}

variable "alert_emails" {
  description = "Correos que reciben las alertas (vacío: sin notificaciones)."
  type        = list(string)
}
