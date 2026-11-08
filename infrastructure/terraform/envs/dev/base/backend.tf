# Estado remoto en el bucket creado por ../../../bootstrap, con bloqueo nativo.
# Cada capa tiene su propio archivo de estado.
terraform {
  backend "s3" {
    bucket       = "usn-tfstate-055147668929"
    key          = "eks/dev/base.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
