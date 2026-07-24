# =============================================================================
# OIDC
# =============================================================================
data "tls_certificate" "eks" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_irsa" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-eks-irsa" })
}

# =============================================================================
# Permission Policy
# =============================================================================

# AWS LBC Policy
data "http" "lbc_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.3.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name   = "${var.name_prefix}-lbc-policy"
  policy = data.http.lbc_policy.response_body
}

# 커스텀 External-DNS Policy
resource "aws_iam_policy" "external_dns_policy" {
  name        = "${var.name_prefix}-external-dns-policy"
  description = "External DNS policy for Spot Dev"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        Resource = [
          "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
        ]
        Resource = "*"
      },
    ]
  })
}

# External-Secrets

# IRSA
locals {
  oidc_provider = replace(aws_iam_openid_connect_provider.eks_irsa.url, "https://", "")

  irsa_roles = {
    lbc = {
      namespace = "kube-system"
      sa_name   = "aws-load-balancer-controller"
    }
    ebs_csi = {
      namespace = "kube-system"
      sa_name   = "ebs-csi-controller-sa"
    }
    eso = {
      namespace = "external-secrets"
      sa_name   = "external-secrets"
    }
    external_dns = {
      namespace = "external-dns"
      sa_name   = "external-dns"
    }
  }
}

# =============================================================================
# IAM Role
# =============================================================================

# Trust Policy
resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles

  name = "${var.name_prefix}-${each.key}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_irsa.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com",
            "${local.oidc_provider}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.sa_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}-role" })
}

# =============================================================================
# Policy Attachment
# =============================================================================
resource "aws_iam_role_policy_attachment" "lbc" {
  policy_arn = aws_iam_policy.lbc.arn
  role       = aws_iam_role.irsa["lbc"].name
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.irsa["ebs_csi"].name
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns_policy.arn
  role       = aws_iam_role.irsa["external_dns"].name
}
