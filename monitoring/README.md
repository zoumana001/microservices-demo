

# Phase 6 — Monitoring Stack

## Components
- **Prometheus** — metrics collection and alerting
- **Grafana** — dashboards at https://grafana.zoumanas.com
- **AlertManager** — Slack notifications
- **Node Exporter** — node-level metrics
- **kube-state-metrics** — K8s object metrics

## Install

```bash
# Add Helm repo
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install with values
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 61.3.2 \
  -f monitoring/values.yaml

# Apply Ingress resources
kubectl apply -f monitoring/grafana-ingress.yaml
kubectl apply -f monitoring/prometheus-ingress.yaml

# Apply custom alerts
kubectl apply -f monitoring/alerting-rules.yaml

# Apply AlertManager config (update webhook URL first)
kubectl apply -f monitoring/alertmanager-config.yaml
```

## Access
- Grafana: https://grafana.zoumanas.com (admin / ZoumGrafana2024!)
- Prometheus: https://prometheus.zoumanas.com

## Key dashboards in Grafana
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace → boutique-app
- Node Exporter / Full