# End-to-End Pipeline Runbook

This is the single doc that ties `terraform/`, `ansible/`, the root
`Jenkinsfile`, `streamingapp/` (Helm chart), and `monitoring/` together into
one flow — from a clean AWS account to a running, monitored app. For details
on any one piece, see:

- Service/API layout → [`CODE_STRUCTURE.md`](../CODE_STRUCTURE.md)
- Local dev / docker-compose → [`README.md`](../README.md)
- Helm command reference → [`helm.md`](../helm.md)
- Monitoring stack detail → [`monitoring/README.md`](../monitoring/README.md)

## Pipeline Flow

```
terraform/bootstrap  →  terraform/ (VPC, EKS, ECR, IAM, SNS, Jenkins EC2)
        │
        ▼
ansible/playbook.yml  →  configures the Jenkins EC2 host
        │
        ▼
Jenkins first-run: install plugins, add AWS/ECR credential, point at this repo
        │
        ▼
Jenkinsfile: Checkout → Build Images → Login to ECR → Tag → Push
        → Deploy to EKS (Helm) → Monitoring (kube-prometheus-stack) → Smoke Test
```

## 1) Provision AWS infrastructure (Terraform)

```bash
# one-time: create the S3 bucket + DynamoDB table used for remote state
cd terraform/bootstrap
terraform init
terraform apply -var="bucket_name=rajsaw-streaming-tfstate" -var="lock_table_name=rajsaw-streaming-tf-locks"

# main infrastructure
cd ../
cp terraform.tfvars.example terraform.tfvars   # fill in jenkins_key_name, allowed CIDRs
terraform init
terraform plan
terraform apply
```

Capture these outputs — they're needed in the next two steps:

```bash
terraform output eks_cluster_name
terraform output jenkins_public_ip
terraform output ecr_repository_urls
terraform output alerts_sns_topic_arn
terraform output alertmanager_sns_role_arn
```

Grant the Jenkins IAM role (`terraform output jenkins_iam_role_arn`) access
inside the cluster — the EKS module creates the cluster but Kubernetes RBAC
is separate:

```bash
aws eks update-kubeconfig --region us-west-1 --name "$(terraform output -raw eks_cluster_name)"
aws eks create-access-entry --cluster-name "$(terraform output -raw eks_cluster_name)" \
  --principal-arn "$(terraform output -raw jenkins_iam_role_arn)"
aws eks associate-access-policy --cluster-name "$(terraform output -raw eks_cluster_name)" \
  --principal-arn "$(terraform output -raw jenkins_iam_role_arn)" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

If Jenkins authenticates via a **stored AWS credential** (a dedicated IAM
user, e.g. `rajsaw-streaming-jenkins-ci`, used for the `rajsaw-ecr-cred`
Jenkins credential) rather than the EC2 instance profile, that IAM
principal needs its own access entry too — the instance role's entry above
does not cover it:

```bash
aws eks create-access-entry --cluster-name "$(terraform output -raw eks_cluster_name)" \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:user/<JENKINS_CI_USER>
aws eks associate-access-policy --cluster-name "$(terraform output -raw eks_cluster_name)" \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:user/<JENKINS_CI_USER> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

Symptom if this is skipped: `helm upgrade` in the `Deploy to EKS` stage
fails with `Error: Kubernetes cluster unreachable: the server has asked for
the client to provide credentials` — network connectivity to the API
server succeeds, but the caller's IAM identity isn't mapped into the
cluster's RBAC.

## 2) Configure the Jenkins host (Ansible)

```bash
cd ansible
cp inventory.ini.example inventory.ini   # set ansible_host = terraform output jenkins_public_ip
ansible-playbook -i inventory.ini playbook.yml --syntax-check   # sanity check first
ansible-playbook -i inventory.ini playbook.yml
```

The last task prints the Jenkins initial admin password. SSH in and confirm
Docker, `kubectl`, `helm`, and `aws` are all on `PATH`:

```bash
ssh -i ~/.ssh/<your-key>.pem ubuntu@$(terraform -chdir=../terraform output -raw jenkins_public_ip)
docker --version && kubectl version --client && helm version && aws --version
```

## 3) Configure Jenkins

1. Browse to `http://<jenkins_public_ip>:8080`, finish the setup wizard with
   the password from step 2.
2. Add credentials: **AWS Credentials** with id `rajsaw-ecr-cred` (matches
   `credentialsId` in `Jenkinsfile`) — access key / secret with ECR push and
   `eks:DescribeCluster` permissions, or better, rely on the instance profile
   Terraform already attached (`aws_iam_instance_profile.jenkins`) and skip
   static keys entirely if the Jenkins AWS plugin picks up instance
   credentials automatically.
3. Create a Pipeline job pointing at this repo's `Jenkinsfile` (or a
   multibranch pipeline if you want PR builds too).
4. If `EKS_CLUSTER` / `ECR_BASE` values in `Jenkinsfile`'s `environment {}`
   block don't match your `terraform.tfvars`, update them to match the
   Terraform outputs before the first run.

## 4) Run the pipeline

Trigger a build. Stages run in this order:

1. **Checkout Code**
2. **Build Images** — 5 services in parallel
3. **Login to ECR**
4. **Tag Images** / **Push Images**
5. **Bootstrap Helm** — self-installs Helm on the agent if missing (mostly a
   fallback now that Ansible provisions Helm directly)
6. **Validate Deployment Tools** — fails fast if `aws`/`kubectl`/`helm` are missing
7. **Deploy to EKS** — `helm upgrade --install streamingapp ./streamingapp`
8. **Monitoring** — installs `kube-prometheus-stack`, applies `monitoring/alerts.yaml`
9. **Smoke Test** — curls each service's actual health endpoint through a
   temporary `kubectl port-forward`; fails the build on any non-200

## 4a) Public access (AWS Load Balancer Controller)

`Deploy to EKS` creates all 5 services as `ClusterIP` by default — nothing
is reachable outside the VPC until this section is done once.

On EKS 1.23+ there is no in-tree AWS cloud provider, so a plain
`Service type: LoadBalancer` stays `Pending` forever without a controller
watching it. `terraform/lb-controller.tf` creates the IAM policy + IRSA
role; the controller itself is installed once, out of band from Terraform:

```bash
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: <terraform output lb_controller_role_arn>
YAML

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=rajsaw-streaming-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-west-1 \
  --set vpcId=<terraform output vpc_id>
```

Only the `frontend` Service is `type: LoadBalancer`
(`streamingapp/values.yaml`'s `frontend.serviceType` / `serviceAnnotations`)
— the other 4 stay `ClusterIP`. The frontend's nginx (`frontend/nginx.conf`)
reverse-proxies `/api/streaming`, `/api/admin`, `/api/chat`, `/socket.io`,
and the catch-all `/api` to those internal services by their in-cluster DNS
names, so **one NLB** is enough for the whole app instead of five.

Get the NLB hostname once it's created:

```bash
kubectl get svc streamingapp-frontend -n streamingapp
```

That hostname has to be baked into the frontend image at *build* time — the
`REACT_APP_STREAMING_PUBLIC_URL` / `REACT_APP_CHAT_SOCKET_URL` build args in
`Jenkinsfile`'s `Build Frontend` stage reference `${PUBLIC_URL}`
(`environment {}` block at the top of the file). If the LoadBalancer Service
is ever deleted and recreated, AWS assigns a new hostname — update
`PUBLIC_URL` there to match, or every subsequent build will bake in a dead
address.

## 5) Verify

```bash
kubectl get pods -n streamingapp
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000
```

Trigger a test alert (e.g. scale a deployment to 0) and confirm it lands in
Slack/Teams/Telegram via the SNS topic and existing `lambda/sns-to-*.py`
functions.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Login to ECR` stage fails with `no basic auth credentials` | `rajsaw-ecr-cred` credential missing/expired in Jenkins | Re-add the AWS credential, or switch to the instance-profile-based auth (no static keys) |
| `Deploy to EKS` fails with `Unauthorized` from kubectl | Jenkins IAM role isn't mapped into the cluster's RBAC | Re-run the `aws eks create-access-entry` / `associate-access-policy` commands from step 1 |
| `Deploy to EKS` fails with `the server has asked for the client to provide credentials` (network reaches the API fine) | The IAM identity behind the `rajsaw-ecr-cred` Jenkins credential (a static-key IAM user, if that's the auth method chosen) has no EKS access entry — only the EC2 instance role does | Grant that IAM user its own access entry, see step 1 |
| `helm upgrade` hangs / times out | New pods can't pull from ECR, or `Insufficient cpu`/`memory` on nodes | `kubectl describe pod <pod>` in `streamingapp` namespace; check node capacity with `kubectl top nodes` (bump `node_desired_size` in `terraform/variables.tf` if genuinely under-provisioned) |
| `Smoke Test` fails for one service only | That service's pod is unhealthy or its `/health`/`/api/health` route changed | `kubectl logs -n streamingapp deploy/streamingapp-<service>`; confirm the path in `monitoring/README.md` still matches `streamingapp/values.yaml` probes |
| Alertmanager never reaches Slack/Teams/Telegram | `topic_arn` in `monitoring/kube-prometheus-stack-values.yaml` doesn't match `terraform output alerts_sns_topic_arn`, or the Alertmanager ServiceAccount isn't annotated with `alertmanager_sns_role_arn` | Re-check both values; `kubectl describe sa kube-prometheus-stack-alertmanager -n monitoring` should show the `eks.amazonaws.com/role-arn` annotation |
| `terraform apply` fails on the S3 backend | `terraform/bootstrap` wasn't applied first, or `backend.tf`'s hardcoded bucket/table names don't match what bootstrap created | Re-run bootstrap, or edit `backend.tf` to match, then `terraform init -reconfigure` |
| Ansible playbook fails on `wait_for: initialAdminPassword` | Jenkins failed to start — usually a Java/memory issue on a too-small instance | `ssh` in, `sudo journalctl -u jenkins -n 100`; bump `jenkins_instance_type` in `terraform/variables.tf` if it's an OOM |

## Rollback

```bash
helm history streamingapp -n streamingapp
helm rollback streamingapp <REVISION> -n streamingapp
```
