# Red del proyecto: VPC en dos AZs, subnets públicas (NAT y balanceadores) y
# privadas (workers EKS y RDS), con un único NAT Gateway para reducir costo.

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = "usn-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(sort(data.aws_availability_zones.available.names), 0, length(var.private_subnet_cidrs))
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Los workers privados no reciben direcciones IPv4 públicas.
  map_public_ip_on_launch = false

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Project     = "usn"
    Environment = var.environment
  }
}
