# Helm and Deployment Commands

This file lists the commands used in this project for local run, image build/push, Helm deployment, and Kubernetes access.

## 1) Local development commands

```bash
docker-compose up --build
```

```bash
cd backend/authService && npm install
cd ../streamingService && npm install
cd ../adminService && npm install
cd ../chatService && npm install
cd ../../frontend && npm install
```

```bash
cd backend/authService && npm run dev
cd backend/streamingService && npm run dev
cd backend/adminService && npm run dev
cd backend/chatService && npm run dev
cd frontend && npm start
```

## 2) CI build and push commands (from Jenkinsfile)

```bash
docker build -t frontend:latest -t frontend:${IMAGE_TAG} frontend
docker build -t authservice:latest -t authservice:${IMAGE_TAG} backend/authService
docker build -f backend/streamingService/Dockerfile -t streamingservice:latest -t streamingservice:${IMAGE_TAG} backend
docker build -f backend/adminService/Dockerfile -t adminservice:latest -t adminservice:${IMAGE_TAG} backend
docker build -f backend/chatService/Dockerfile -t chatservice:latest -t chatservice:${IMAGE_TAG} backend
```

```bash
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

```bash
docker tag frontend:latest ${ECR_BASE}/frontend:latest
docker tag frontend:${IMAGE_TAG} ${ECR_BASE}/frontend:${IMAGE_TAG}
docker tag authservice:latest ${ECR_BASE}/authservice:latest
docker tag authservice:${IMAGE_TAG} ${ECR_BASE}/authservice:${IMAGE_TAG}
docker tag streamingservice:latest ${ECR_BASE}/streamingservice:latest
docker tag streamingservice:${IMAGE_TAG} ${ECR_BASE}/streamingservice:${IMAGE_TAG}
docker tag adminservice:latest ${ECR_BASE}/adminservice:latest
docker tag adminservice:${IMAGE_TAG} ${ECR_BASE}/adminservice:${IMAGE_TAG}
docker tag chatservice:latest ${ECR_BASE}/chatservice:latest
docker tag chatservice:${IMAGE_TAG} ${ECR_BASE}/chatservice:${IMAGE_TAG}
```

```bash
docker push ${ECR_BASE}/frontend:latest
docker push ${ECR_BASE}/frontend:${IMAGE_TAG}
docker push ${ECR_BASE}/authservice:latest
docker push ${ECR_BASE}/authservice:${IMAGE_TAG}
docker push ${ECR_BASE}/streamingservice:latest
docker push ${ECR_BASE}/streamingservice:${IMAGE_TAG}
docker push ${ECR_BASE}/adminservice:latest
docker push ${ECR_BASE}/adminservice:${IMAGE_TAG}
docker push ${ECR_BASE}/chatservice:latest
docker push ${ECR_BASE}/chatservice:${IMAGE_TAG}
```

## 3) Helm chart commands

```bash
cd streamingapp
helm lint .
helm template streamingapp .
helm install streamingapp . --namespace streamingapp --create-namespace
helm upgrade --install streamingapp . --namespace streamingapp
helm uninstall streamingapp --namespace streamingapp
```

## 4) Kubernetes access commands (from chart NOTES)

### HTTPRoute mode

```bash
export APP_HOSTNAME=$(kubectl get --namespace <gateway-namespace-or-release-namespace> gateway/<gateway-name> -o jsonpath="{.spec.listeners[0].hostname}")
kubectl get --namespace <gateway-namespace-or-release-namespace> gateway/<gateway-name> -o yaml
```

### NodePort mode

```bash
export NODE_PORT=$(kubectl get --namespace <namespace> -o jsonpath="{.spec.ports[0].nodePort}" services <release-name>-frontend)
export NODE_IP=$(kubectl get nodes --namespace <namespace> -o jsonpath="{.items[0].status.addresses[0].address}")
echo http://$NODE_IP:$NODE_PORT
```

### LoadBalancer mode

```bash
kubectl get --namespace <namespace> svc -w <release-name>-frontend
export SERVICE_IP=$(kubectl get svc --namespace <namespace> <release-name>-frontend --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
echo http://$SERVICE_IP:<frontend-port>
```

### ClusterIP mode (port-forward)

```bash
export POD_NAME=$(kubectl get pods --namespace <namespace> -l "app.kubernetes.io/name=<chart-name>,app.kubernetes.io/instance=<release-name>,app.kubernetes.io/component=frontend" -o jsonpath="{.items[0].metadata.name}")
export CONTAINER_PORT=$(kubectl get pod --namespace <namespace> $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
kubectl --namespace <namespace> port-forward $POD_NAME 8080:$CONTAINER_PORT
```
