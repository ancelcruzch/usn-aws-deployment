# Capa platform del ambiente dev (sin secretos). Los valores por defecto están
# en variables.tf; aquí solo lo que conviene ver de un vistazo.
aws_region          = "us-east-2"
cluster_name        = "usn-cluster"
environment         = "dev"
node_instance_types = ["c7i-flex.large"]
