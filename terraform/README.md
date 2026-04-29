# zoum_cluster — Phase 1 Terraform Infrastructure

## What this provisions

| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16`, 2 public + 2 private subnets across 2 AZs |
| EKS cluster | `zoum_cluster`, Kubernetes 1.30, private endpoint only |
| Node group | `t3.medium`, min 1 / desired 2 / max 4, in private subnets |
| Bastion host | `t3.micro`, Amazon Linux 2023, in public subnet, kubectl+helm pre-installed |
| OIDC provider | Enables IRSA for pods |
| IRSA roles | `lbc`, `external_dns`, `image_updater` — policies attached in later phases |
| Route53 zone | `zoumanas.com` public hosted zone |
| ACM certificate | `zoumanas.com` + `*.zoumanas.com`, DNS-validated automatically |
| S3 backend | `zoum-terraform-state` with versioning + encryption |
| DynamoDB lock | `zoum-terraform-locks` |

## Folder structure

```
zoum-terraform/
├── bootstrap.sh          ← run once before terraform init
├── Makefile              ← convenience commands
├── modules/
│   ├── vpc/              ← VPC, subnets, IGW, NAT, route tables
│   ├── eks/              ← Cluster, node group, OIDC, IRSA roles
│   ├── bastion/          ← EC2 bastion in public subnet
│   ├── route53/          ← Hosted zone for zoumanas.com
│   └── acm/              ← Wildcard cert + DNS validation
└── envs/
    └── prod/
        ├── backend.tf    ← S3 remote state
        ├── providers.tf
        ├── variables.tf
        ├── main.tf       ← module calls
        └── outputs.tf
```

## Prerequisites

```bash
# Install tools
brew install terraform awscli kubectl helm   # macOS
# or follow https://developer.hashicorp.com/terraform/install

# Authenticate to AWS
aws configure          # or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

# Create an EC2 key pair for the bastion (one-time)
aws ec2 create-key-pair \
  --key-name zoum-bastion-key \
  --query "KeyMaterial" \
  --output text > zoum-bastion-key.pem
chmod 400 zoum-bastion-key.pem
```

## Deployment

```bash
# Step 1 — create S3 bucket and DynamoDB table (run once only)
make bootstrap

# Step 2 — initialise Terraform
make init

# Step 3 — preview (read this carefully before applying)
make plan

# Step 4 — apply (~15 min, EKS cluster is the slow part)
make apply

# Step 5 — configure kubectl
make kubeconfig

# Step 6 — verify nodes are Ready
kubectl get nodes
```

## After apply: update your registrar

The `make outputs` command prints something like:

```
route53_nameservers = [
  "ns-123.awsdns-45.com",
  "ns-678.awsdns-90.net",
  ...
]
```

Log in to wherever you registered `zoumanas.com` and replace the
nameservers with these four values. ACM certificate validation
completes automatically once DNS propagates (~5 min).

Verify propagation:
```bash
dig NS zoumanas.com
```

## SSH to bastion

```bash
ssh -i zoum-bastion-key.pem ec2-user@$(terraform -chdir=envs/prod output -raw bastion_public_ip)
```

From the bastion, kubectl is already configured for zoum_cluster:
```bash
kubectl get nodes
kubectl get pods -A
```

## Accessing the private EKS API from your laptop

Use an SSH tunnel through the bastion:
```bash
ssh -i zoum-bastion-key.pem \
    -L 8443:<cluster_endpoint>:443 \
    ec2-user@<bastion_ip> \
    -N &

# Then point kubectl at localhost:8443
```

## Unlock stuck state

If `terraform apply` crashes mid-run:
```bash
make unlock
```

## Outputs used in later phases

| Output | Used in |
|---|---|
| `irsa_role_arns.lbc` | Phase 4 — AWS Load Balancer Controller Helm install |
| `irsa_role_arns.external_dns` | Phase 4 — External DNS Helm install |
| `irsa_role_arns.image_updater` | Phase 3 — ArgoCD Image Updater |
| `acm_certificate_arn` | Phase 4 — Gateway annotation |
| `route53_zone_id` | Phase 4 — External DNS `txtOwnerId` |
| `oidc_provider_arn` | Phase 3/4 — any new IRSA role you add |
