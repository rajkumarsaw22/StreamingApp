# --- Jenkins EC2 instance role: push/pull ECR, describe/update-kubeconfig for EKS ---

data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# AmazonEKSClusterPolicy is for the cluster's own service role (what EKS uses to
# call EC2/ELB on your behalf) and does NOT grant eks:DescribeCluster — the
# permission `aws eks update-kubeconfig` actually needs for a caller like Jenkins.
# Cluster-side RBAC (mapping this role to a Kubernetes group) still needs to be
# granted via the EKS access entries / aws-auth after `terraform apply`; see
# docs/PIPELINE.md for the `aws eks create-access-entry` step.
data "aws_iam_policy_document" "jenkins_eks_describe" {
  statement {
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
    ]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_role_policy" "jenkins_eks_describe" {
  name   = "${var.project}-jenkins-eks-describe"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins_eks_describe.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-jenkins-instance-profile"
  role = aws_iam_role.jenkins.name
}

# --- IRSA role: lets streamingService/adminService pods reach S3 without static creds ---

data "aws_iam_policy_document" "s3_access_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:streamingapp:streamingapp-s3-access"]
    }
  }
}

resource "aws_iam_role" "pod_s3_access" {
  name               = "${var.project}-pod-s3-access"
  assume_role_policy = data.aws_iam_policy_document.s3_access_assume.json

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "pod_s3_access" {
  role       = aws_iam_role.pod_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
