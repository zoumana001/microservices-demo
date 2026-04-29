# ─────────────────────────────────────────────
# Global
# ─────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

# ─────────────────────────────────────────────
# Network
# ─────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the two private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ─────────────────────────────────────────────
# EKS
# ─────────────────────────────────────────────
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "zoum_cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

# ─────────────────────────────────────────────
# Bastion
# ─────────────────────────────────────────────
variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_cidr" {
  description = "Your IP CIDR allowed to SSH to the bastion"
  type        = string
  # Replace with your actual IP: curl ifconfig.me
  default     = "0.0.0.0/0"
}

variable "bastion_key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
  default     = "zoum-bastion-key"
}

# ─────────────────────────────────────────────
# DNS and TLS
# ─────────────────────────────────────────────
variable "domain_name" {
  description = "Root domain managed by Route53"
  type        = string
  default     = "zoumanas.com"
}
