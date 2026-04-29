data "aws_availability_zones" "available" {}

# ─────────────────────────────────────────────
# MODULE: VPC
# ─────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = data.aws_availability_zones.available.names
}

# ─────────────────────────────────────────────
# MODULE: EKS
# ─────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired       = var.node_desired
  node_min           = var.node_min
  node_max           = var.node_max
}

# ─────────────────────────────────────────────
# MODULE: Bastion host
# ─────────────────────────────────────────────
module "bastion" {
  source = "../../modules/bastion"

  cluster_name         = var.cluster_name
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnet_ids[0]
  instance_type        = var.bastion_instance_type
  key_name             = var.bastion_key_name
  allowed_cidr         = var.bastion_allowed_cidr
  eks_cluster_sg_id    = module.eks.cluster_security_group_id
}

# ─────────────────────────────────────────────
# MODULE: Route53
# ─────────────────────────────────────────────
module "route53" {
  source      = "../../modules/route53"
  domain_name = var.domain_name
}

# ─────────────────────────────────────────────
# MODULE: ACM
# ─────────────────────────────────────────────
module "acm" {
  source          = "../../modules/acm"
  domain_name     = var.domain_name
  route53_zone_id = module.route53.zone_id

  depends_on = [module.route53]
}
