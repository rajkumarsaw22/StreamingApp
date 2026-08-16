variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Short name used to prefix/tag resources"
  type        = string
  default     = "rajsaw-streaming"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1c"]
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster (matches EKS_CLUSTER in Jenkinsfile)"
  type        = string
  default     = "rajsaw-streaming-cluster"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "ecr_repositories" {
  description = "ECR repository names, matching Jenkinsfile ECR_BASE image names"
  type        = list(string)
  default     = ["frontend", "authservice", "streamingservice", "adminservice", "chatservice"]
}

variable "ecr_repo_prefix" {
  description = "Prefix applied before each repo name, matching batch-14/rajsaw in Jenkinsfile's ECR_BASE"
  type        = string
  default     = "batch-14/rajsaw"
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "jenkins_key_name" {
  description = "Existing EC2 key pair name used to SSH into the Jenkins host (for Ansible)"
  type        = string
}

variable "jenkins_allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the Jenkins host"
  type        = string
}

variable "jenkins_allowed_web_cidr" {
  description = "CIDR allowed to reach the Jenkins web UI (port 8080)"
  type        = string
}

variable "tf_state_bucket" {
  description = "Name of the S3 bucket used for remote state (must be globally unique, created by bootstrap)"
  type        = string
  default     = "rajsaw-streaming-tfstate"
}

variable "tf_lock_table" {
  description = "DynamoDB table name used for state locking"
  type        = string
  default     = "rajsaw-streaming-tf-locks"
}

variable "slack_lambda_arn" {
  description = "ARN of the already-deployed lambda/sns-to-slack.py function, if any"
  type        = string
  default     = ""
}

variable "teams_lambda_arn" {
  description = "ARN of the already-deployed lambda/sns-to-teams.py function, if any"
  type        = string
  default     = ""
}

variable "telegram_lambda_arn" {
  description = "ARN of the already-deployed lambda/sns-to-telegram.py function, if any"
  type        = string
  default     = ""
}
