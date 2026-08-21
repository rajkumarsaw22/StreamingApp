# AWS Load Balancer Controller: lets the cluster provision real AWS NLBs/ALBs
# for Service type=LoadBalancer / Ingress resources. EKS 1.23+ removed the
# in-tree AWS cloud provider, so without this controller a LoadBalancer
# Service just stays Pending forever with no external IP.

resource "aws_iam_policy" "lb_controller" {
  name   = "${var.project}-aws-lb-controller"
  policy = file("${path.module}/files/aws-lb-controller-iam-policy.json")

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

output "lb_controller_role_arn" {
  description = "Annotate the aws-load-balancer-controller ServiceAccount (kube-system) with this ARN"
  value       = aws_iam_role.lb_controller.arn
}
