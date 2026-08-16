output "eks_cluster_name" {
  description = "Feeds EKS_CLUSTER in the Jenkinsfile environment block"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "Feeds ECR_BASE in the Jenkinsfile (strip the /<service> suffix)"
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "jenkins_public_ip" {
  description = "Target host for ansible/inventory.ini"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_iam_role_arn" {
  value = aws_iam_role.jenkins.arn
}

output "pod_s3_access_role_arn" {
  description = "Annotate the streamingapp-s3-access ServiceAccount with this ARN"
  value       = aws_iam_role.pod_s3_access.arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alerts_sns_topic_arn" {
  description = "Feeds monitoring/kube-prometheus-stack-values.yaml alertmanager sns_configs"
  value       = aws_sns_topic.alerts.arn
}

output "alertmanager_sns_role_arn" {
  description = "Annotate the Alertmanager ServiceAccount (monitoring namespace) with this ARN"
  value       = aws_iam_role.alertmanager_sns.arn
}
