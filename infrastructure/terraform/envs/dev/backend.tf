# Estado remoto compartido por el equipo, en S3 con bloqueo nativo (use_lockfile).
# La configuración (bucket, key, region) se pasa en `terraform init` desde
# backend.hcl, que se genera a partir de backend.hcl.example. El bucket lo crea
# la configuración de ../../bootstrap (ver README).
terraform {
  backend "s3" {}
}
