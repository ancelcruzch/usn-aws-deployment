# Un repositorio por imagen. El CI/CD publica tags inmutables (SHA del commit),
# de modo que cada versión desplegada se puede rastrear hasta su commit.
resource "aws_ecr_repository" "app" {
  for_each = var.repositories

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  # Permite que `terraform destroy` elimine el repositorio aunque tenga imágenes.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Conserva solo las últimas N imágenes para controlar el costo de almacenamiento.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each = aws_ecr_repository.app

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar las ultimas ${var.keep_last_images} imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last_images
      }
      action = {
        type = "expire"
      }
    }]
  })
}
