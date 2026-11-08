output "identifier" {
  description = "Identificador de la instancia RDS."
  value       = aws_db_instance.mysql.identifier
}

output "address" {
  description = "Host de la base de datos."
  value       = aws_db_instance.mysql.address
}

output "jdbc_url" {
  description = "URL JDBC para el backend."
  value       = "jdbc:mysql://${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${var.db_name}"
}

output "secret_arn" {
  description = "ARN del secreto con las credenciales."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Nombre del secreto con las credenciales."
  value       = aws_secretsmanager_secret.db.name
}
