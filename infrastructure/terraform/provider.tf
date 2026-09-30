provider "aws" {
  region = var.aws_region

  # Usa la cadena de credenciales de AWS (incluido AWS_PROFILE); sin claves aquí.
  allowed_account_ids = ["912759111826"]

  default_tags {
    tags = {
      Project     = "usn"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
