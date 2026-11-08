output "budget_name" {
  description = "Nombre del presupuesto en AWS Budgets."
  value       = aws_budgets_budget.monthly.name
}
