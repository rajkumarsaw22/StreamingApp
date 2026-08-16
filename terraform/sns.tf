# Alerts topic: Alertmanager (monitoring/alerts.yaml + kube-prometheus-stack-values.yaml)
# publishes here natively via sns_configs; the existing lambda/sns-to-{slack,teams,telegram}.py
# functions subscribe to it and fan the notification out to each channel.

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

# Lets the EKS pod IAM role (via IRSA, reusing pod_s3_access-style trust) publish to
# this topic. Alertmanager's SNS receiver signs requests using AWS SDK credentials
# resolved from its pod's IRSA role — see monitoring/README.md for the ServiceAccount
# annotation and the policy attached here.
data "aws_iam_policy_document" "alertmanager_sns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:monitoring:kube-prometheus-stack-alertmanager"]
    }
  }
}

resource "aws_iam_role" "alertmanager_sns" {
  name               = "${var.project}-alertmanager-sns"
  assume_role_policy = data.aws_iam_policy_document.alertmanager_sns_assume.json

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "alertmanager_sns_publish" {
  name = "${var.project}-alertmanager-sns-publish"
  role = aws_iam_role.alertmanager_sns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.alerts.arn
    }]
  })
}

# Optional: subscribe already-deployed notifier Lambdas by ARN. Leave the
# corresponding variable empty (default) to skip a channel that isn't deployed yet.
resource "aws_sns_topic_subscription" "slack" {
  count     = var.slack_lambda_arn == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = var.slack_lambda_arn
}

resource "aws_lambda_permission" "slack_sns" {
  count         = var.slack_lambda_arn == "" ? 0 : 1
  statement_id  = "AllowSNSInvokeSlack"
  action        = "lambda:InvokeFunction"
  function_name = var.slack_lambda_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "teams" {
  count     = var.teams_lambda_arn == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = var.teams_lambda_arn
}

resource "aws_lambda_permission" "teams_sns" {
  count         = var.teams_lambda_arn == "" ? 0 : 1
  statement_id  = "AllowSNSInvokeTeams"
  action        = "lambda:InvokeFunction"
  function_name = var.teams_lambda_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "telegram" {
  count     = var.telegram_lambda_arn == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = var.telegram_lambda_arn
}

resource "aws_lambda_permission" "telegram_sns" {
  count         = var.telegram_lambda_arn == "" ? 0 : 1
  statement_id  = "AllowSNSInvokeTelegram"
  action        = "lambda:InvokeFunction"
  function_name = var.telegram_lambda_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}
