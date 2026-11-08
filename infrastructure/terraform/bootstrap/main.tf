# Crea el bucket S3 del estado remoto. Se ejecuta una sola vez por cuenta, con
# estado local (este directorio no puede guardar su estado en el bucket que crea).
terraform {
  required_version = ">= 1.12.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59.0, < 7.0.0"
    }
  }
}

variable "aws_region" {
  description = "Región del bucket de estado."
  type        = string
  default     = "us-east-2"
}

variable "aws_account_id" {
  description = "Cuenta AWS permitida."
  type        = string
  default     = "055147668929"
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project   = "usn"
      ManagedBy = "Terraform"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket = "usn-tfstate-${var.aws_account_id}"

  # Al finalizar el curso: vaciar y borrar con `terraform destroy` aquí
  # (después de destruir la infraestructura principal).
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

output "state_bucket" {
  description = "Bucket a usar en backend.hcl."
  value       = aws_s3_bucket.state.bucket
}
