# ─────────────────────────────────────────────
# Latest Amazon Linux 2023 AMI
# ─────────────────────────────────────────────
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────
# Security group — bastion host
# Inbound: SSH from your IP only
# Outbound: unrestricted (needs to reach EKS API
#           and pull packages from the internet)
# ─────────────────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "Bastion host - SSH ingress from allowed CIDR only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-bastion-sg" }
}

# ─────────────────────────────────────────────
# Allow bastion to reach the EKS API server
# (port 443 on the cluster security group)
# ─────────────────────────────────────────────
resource "aws_security_group_rule" "bastion_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.eks_cluster_sg_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow bastion to reach EKS API server"
}

# ─────────────────────────────────────────────
# IAM role — lets the bastion call EKS describe
# (needed for aws eks update-kubeconfig)
# ─────────────────────────────────────────────
resource "aws_iam_role" "bastion" {
  name = "${var.cluster_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "bastion_eks" {
  name = "${var.cluster_name}-bastion-eks-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeCluster"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.cluster_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ─────────────────────────────────────────────
# Bastion EC2 instance
# Sits in a public subnet with a public IP.
# On boot: installs kubectl, awscli, helm, and
# configures kubeconfig automatically.
# ─────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  # Harden: no public instance metadata v1 (IMDSv2 only)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # System update
    dnf update -y

    # AWS CLI v2 (already present on AL2023 but ensure latest)
    dnf install -y awscli

    # kubectl — match your cluster version (1.30)
    curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl

    # Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Configure kubeconfig for the zoum_cluster
    aws eks update-kubeconfig \
      --region us-east-1 \
      --name zoum_cluster \
      --kubeconfig /home/ec2-user/.kube/config

    chown -R ec2-user:ec2-user /home/ec2-user/.kube

    echo "Bastion bootstrap complete" >> /var/log/bastion-init.log
  EOF

  tags = { Name = "${var.cluster_name}-bastion" }
}
