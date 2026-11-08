variable "repositories" {
  description = "Nombres de los repositorios ECR (uno por imagen)."
  type        = set(string)
}

variable "keep_last_images" {
  description = "Imágenes que se conservan por repositorio."
  type        = number
}
