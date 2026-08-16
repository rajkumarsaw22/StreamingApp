# Monitoring: Prometheus, Grafana, Alertmanager

Deploys the `prometheus-community/kube-prometheus-stack` chart (Prometheus +
Grafana + Alertmanager + node-exporter + kube-state-metrics in one release)
into the EKS cluster, plus a `PrometheusRule` for StreamingApp-specific
alerts. Alertmanager publishes straight to the SNS topic Terraform creates
(`terraform output alerts_sns_topic_arn`), which the existing
`lambda/sns-to-{slack,teams,telegram}.py` functions already know how to
consume once subscribed (`terraform apply -var slack_lambda_arn=... `, etc).

## One-time setup

1. Apply the Terraform in `terraform/sns.tf` (SNS topic + Alertmanager IRSA
   role) as part of the normal `terraform apply` in `terraform/`.
2. Note two outputs:
   - `alerts_sns_topic_arn` → paste into
     `kube-prometheus-stack-values.yaml`'s `alertmanager.config.receivers[0].sns_configs[0].topic_arn`.
   - `alertmanager_sns_role_arn` → annotate the Alertmanager ServiceAccount
     with it (either edit the values file's
     `alertmanager.alertmanagerSpec.serviceAccountAnnotations`, or `kubectl
     annotate serviceaccount kube-prometheus-stack-alertmanager -n monitoring
     eks.amazonaws.com/role-arn=<arn>` after first install).

## Install / upgrade

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/kube-prometheus-stack-values.yaml \
  --set grafana.adminPassword="$GRAFANA_ADMIN_PASSWORD"

kubectl apply -f monitoring/alerts.yaml
```

This is also run as the `Monitoring` stage in the root `Jenkinsfile`, right
after `Deploy to EKS`.

## Accessing Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000, user: admin, password: $GRAFANA_ADMIN_PASSWORD
```

Default dashboards (Kubernetes / Compute Resources, Node Exporter, etc.) are
enabled out of the box via `grafana.defaultDashboardsEnabled: true`. Import
additional community dashboards by ID from grafana.com/dashboards as needed
— none are StreamingApp-specific since the services don't currently expose a
`/metrics` endpoint (see Known Limitation below).

## Alerts (`alerts.yaml`)

Five rules scoped to the `streamingapp` namespace, all derived from
kube-state-metrics / cAdvisor (no app instrumentation required):

- `StreamingAppPodCrashLooping`
- `StreamingAppDeploymentReplicasMismatch`
- `StreamingAppPodHighMemory`
- `StreamingAppPodHighCPU`
- `StreamingAppDeploymentDown`

## Known Limitation

None of the StreamingApp services (`authService`, `streamingService`,
`adminService`, `chatService`, `frontend`) currently expose a Prometheus
`/metrics` endpoint, so alerting here is limited to cluster/pod-level signals
(restarts, replica counts, CPU/memory vs. limits) rather than
application-level metrics (request latency, error rate, active chat
connections, etc.). Adding `prom-client` to each service and a
`ServiceMonitor` per service would be the natural next step but is out of
scope for this pass.
