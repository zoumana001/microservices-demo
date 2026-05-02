# GitOps Platform on AWS EKS

A production-grade GitOps platform built on Amazon EKS featuring a complete CI/CD pipeline with automated security scanning, GitOps continuous delivery, centralized logging, and real-time monitoring.

**Live demo:**
- App → [https://app.zoumanas.com](https://app.zoumanas.com)
- ArgoCD → [https://argocd.zoumanas.com](https://argocd.zoumanas.com)
- Grafana → [https://grafana.zoumanas.com](https://grafana.zoumanas.com)
- Kibana → [https://kibana.zoumanas.com](https://kibana.zoumanas.com)

---

## Architecture overview

```
Developer → GitHub → GitHub Actions CI → GHCR
                          ↓
                   gitops-manifests repo
                          ↓
                       ArgoCD
                          ↓
              AWS EKS (zoum_cluster)
           ┌──────────┬────────────┐
           │  app     │  logging   │
           │  ArgoCD  │  monitoring│
           └──────────┴────────────┘
```

The entire delivery process is automated. A `git push` triggers security scanning, builds a container image, and deploys to the cluster — with zero manual `kubectl apply`.

---

## Tech stack

| Layer | Technology |
|---|---|
| Infrastructure | Terraform (modules: VPC, EKS, Bastion, ACM, Route53) |
| Container registry | GitHub Container Registry (GHCR) |
| CI pipeline | GitHub Actions |
| Secret scanning | Gitleaks |
| IaC scanning | Checkov |
| Code quality | SonarQube / SonarCloud |
| Image scanning | Trivy |
| GitOps | ArgoCD + ArgoCD Image Updater |
| Application | Google Online Boutique (12 microservices) |
| Ingress | AWS Load Balancer Controller |
| DNS | External DNS + Route53 |
| TLS | AWS Certificate Manager (ACM) |
| Logging | ECK (Elasticsearch + Kibana + Filebeat) |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana + AlertManager) |
| Auto-scaling | Horizontal Pod Autoscaler (HPA) |
| Notifications | Slack |

---

## Repository structure

```
microservices-demo/
├── .github/
│   └── workflows/
│       └── ci.yaml              # Full CI pipeline
├── src/                         # Application source code
│   └── frontend/
│       └── Dockerfile           # Hardened multi-stage build
├── manifests/
│   ├── apps/
│   │   └── boutique-app/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── kustomization.yaml
│   └── argocd/
│       └── application.yaml     # ArgoCD Application manifest
├── terraform/
│   ├── modules/
│   │   ├── vpc/                 # VPC, subnets, IGW, NAT
│   │   ├── eks/                 # Cluster, node group, OIDC, IRSA
│   │   ├── bastion/             # Bastion host with auto-config
│   │   ├── route53/             # Hosted zone
│   │   └── acm/                 # Wildcard TLS certificate
│   └── envs/
│       └── prod/                # Production environment
├── logging/                     # ECK stack manifests
├── monitoring/                  # Prometheus stack Helm values
├── hpa/                         # HorizontalPodAutoscaler manifests
├── .gitleaks.toml               # Gitleaks configuration
├── .checkov.yaml                # Checkov skip rules
├── .trivyignore                 # Accepted CVEs
└── sonar-project.properties     # SonarQube project config
```

---

## CI pipeline

Every push to `main` runs 7 stages in sequence:

```
git push
    │
    ├── Gitleaks ──── secrets in code? → block
    ├── Checkov ───── IaC misconfiguration? → block
    ├── SonarQube ─── quality gate failed? → block
    │
    └── (all pass) → Build Docker image
                          │
                          └── Trivy ── CVEs in image? → block
                                   │
                                   └── (pass) → Push to GHCR
                                                    │
                                                    └── Update manifests → ArgoCD syncs → Slack
```

The pipeline blocks deployment on any CRITICAL or HIGH severity finding. The image only reaches the cluster if all security gates pass.

---

## Infrastructure

### Prerequisites

```bash
# Tools required
terraform >= 1.6
aws cli v2
kubectl
helm >= 3.x
```

### Bootstrap

```bash
cd terraform/

# Create S3 state bucket and DynamoDB lock table (run once)
bash bootstrap.sh

# Initialize and deploy
make init
make plan
make apply   # ~15 minutes

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name zoum_cluster
```

### What Terraform creates

| Resource | Details |
|---|---|
| VPC | 10.0.0.0/16, 2 public + 2 private subnets across 2 AZs |
| EKS cluster | zoum_cluster, Kubernetes 1.30, private endpoint |
| Node group | t3.medium, min 1 / desired 2 / max 4 |
| Bastion host | t3.micro, kubectl + helm pre-installed |
| OIDC provider | Enables IRSA for pods |
| IRSA roles | LBC, External DNS, ArgoCD Image Updater |
| Route53 zone | zoumanas.com |
| ACM certificate | *.zoumanas.com, DNS-validated |

---

## GitOps setup

### Install ArgoCD

```bash
# From the bastion host
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.0/manifests/install.yaml

# Connect manifests repo and deploy the application
kubectl apply -f manifests/argocd/application.yaml -n argocd
```

ArgoCD watches `gitops-manifests` and automatically syncs any change. Manual `kubectl apply` is never needed after this point.

---

## Networking

```bash
# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=zoum_cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Install External DNS
helm install external-dns external-dns/external-dns \
  --namespace kube-system \
  --set provider.name=aws \
  --set txtOwnerId=<ZONE_ID> \
  --set sources[0]=ingress
```

Each Ingress object automatically provisions an ALB and creates a Route53 DNS record. TLS is terminated at the ALB using the ACM wildcard certificate.

---

## Logging

ECK (Elastic Cloud on Kubernetes) manages the full logging stack:

```bash
# Install ECK operator
kubectl create -f https://download.elastic.co/downloads/eck/2.13.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.13.0/operator.yaml

# Deploy Elasticsearch, Kibana, and Filebeat
kubectl apply -f logging/
```

Filebeat runs as a DaemonSet on every node, collecting container logs and enriching them with Kubernetes metadata before shipping to Elasticsearch. Logs are searchable at `https://kibana.zoumanas.com`.

---

## Monitoring

The kube-prometheus-stack deploys Prometheus, Grafana, AlertManager, Node Exporter, and kube-state-metrics in a single Helm release:

```bash
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/values.yaml
```

Custom PrometheusRules fire Slack alerts when:
- Frontend replicas drop below 1
- A pod enters CrashLoopBackOff more than 3 times in 15 minutes
- Node memory exceeds 85%

Dashboards available at `https://grafana.zoumanas.com` (admin / see secret).

---

## Auto-scaling

HPA scales the frontend between 2 and 6 replicas based on CPU and memory:

```bash
kubectl apply -f hpa/frontend-hpa.yaml
```

```yaml
minReplicas: 2
maxReplicas: 6
metrics:
  - cpu target: 50%
  - memory target: 70%
```

---

## Security highlights

- EKS API server is private — only accessible via the Bastion host
- All pods run as non-root with `readOnlyRootFilesystem: true`
- IRSA used for all AWS API access — no static credentials anywhere
- IMDSv2 enforced on all EC2 instances
- Container images built with distroless base (minimal attack surface)
- Every image scanned by Trivy before reaching the cluster
- Secrets never committed — Gitleaks blocks on every push

---

## Live endpoints

| URL | Description |
|---|---|
| https://app.zoumanas.com | Online Boutique — microservices demo app |
| https://argocd.zoumanas.com | ArgoCD GitOps dashboard |
| https://kibana.zoumanas.com | Kibana — centralized log search |
| https://grafana.zoumanas.com | Grafana — cluster metrics and dashboards |
| https://prometheus.zoumanas.com | Prometheus — metrics query interface |

---

## Author

**Zoumana Ouattara**
- GitHub: [@zoumana001](https://github.com/zoumana001)
- LinkedIn: [linkedin.com/in/zoumana-ouattara](https://www.linkedin.com/in/zoumana-ouattara-111038281/)