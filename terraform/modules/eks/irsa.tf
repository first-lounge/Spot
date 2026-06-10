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
# IRSA
# =============================================================================

# LBC Policy
data "http" "lbc_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.3.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name   = "${var.name_prefix}-lbc-policy"
  policy = data.http.lbc_policy.response_body
}

# IRSA
locals {
  oidc_provider = replace(aws_iam_openid_connect_provider.eks_irsa.url, "https://", "")

  irsa_roles = {
    lbc = {
      sa_name = "aws-load-balancer-controller"
    }
    ebs_csi = {
      sa_name = "ebs-csi-controller-sa"
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa_roles

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
            "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:${each.value.sa_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}-role" })
}

resource "aws_iam_role_policy_attachment" "lbc" {
  policy_arn = aws_iam_policy.lbc.arn
  role       = aws_iam_role.irsa["lbc"].name
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.irsa["ebs_csi"].name
}
