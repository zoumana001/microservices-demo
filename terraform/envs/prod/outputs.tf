# ─── VPC ───────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ─── EKS ───────────────────────────────────────
output "cluster_name" {
  description = "EKS cluster name — use in kubectl and Helm commands"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_data" {
  description = "Base64 cluster CA certificate"
  value       = module.eks.cluster_ca_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used in IRSA trust policies"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  value       = module.eks.oidc_provider_url
}

output "irsa_role_arns" {
  description = "IAM role ARNs for IRSA — used in Phase 3 and Phase 4 Helm installs"
  value       = module.eks.irsa_role_arns
}

# ─── Bastion ───────────────────────────────────
output "bastion_public_ip" {
  description = "SSH to bastion: ssh -i zoum-bastion-key.pem ec2-user@<this IP>"
  value       = module.bastion.public_ip
}

# ─── DNS and TLS ───────────────────────────────
output "route53_zone_id" {
  description = "Route53 hosted zone ID — used by External DNS"
  value       = module.route53.zone_id
}

output "route53_nameservers" {
  description = "IMPORTANT: set these NS records at your registrar (zoumanas.com)"
  value       = module.route53.nameservers
}

output "acm_certificate_arn" {
  description = "ACM cert ARN — paste into Gateway annotation in Phase 4"
  value       = module.acm.certificate_arn
}

# ─── kubectl config helper ─────────────────────
output "kubeconfig_command" {
  description = "Run this after apply to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
