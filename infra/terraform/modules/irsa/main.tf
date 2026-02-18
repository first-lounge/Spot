data "tls_certificate" "oidc" {
  url = var.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.common_tags
}

locals {
  namespaces = toset([
    for k, v in var.service_accounts : v.namespace
    if v.namespace != "kube-system" && v.namespace != "default"
  ])
}

resource "aws_iam_role" "service_account" {
  for_each = var.service_accounts

  name = "${var.name_prefix}-${each.key}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Condition = {
        StringEquals = {
          "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
          "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.common_tags
}

data "aws_iam_policy_document" "alb_controller" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:Describe*",
      "elasticloadbalancing:*",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
      "waf-regional:*",
      "wafv2:*",
      "shield:*",
      "cognito-idp:DescribeUserPoolClient"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.name_prefix}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.aws_iam_policy_document.alb_controller.json
  tags        = var.common_tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.service_account["aws_load_balancer_controller"].name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for k, v in var.service_accounts : k => v
    if try(length(v.policy_arn), 0) > 0
  }

  role       = aws_iam_role.service_account[each.key].name
  policy_arn = each.value.policy_arn
}


resource "kubernetes_namespace" "this" {
  for_each = local.namespaces

  metadata {
    name = each.value
  }
}

resource "kubernetes_service_account" "this" {
  for_each = var.service_accounts

  metadata {
    name      = each.value.service_account
    namespace = each.value.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.service_account[each.key].arn
    }
  }

  depends_on = [kubernetes_namespace.this]
}
