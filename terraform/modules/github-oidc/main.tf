# =============================================================================
# OIDC
# =============================================================================
data "tls_certificate" "github" {
  url = var.github_oidc_url
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  url             = var.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-github-oidc" })
}

# =============================================================================
# IAM Role & Policy 
# =============================================================================

# 커스텀 ECR Push IAM 정책 문서(Document) 정의
data "aws_iam_policy_document" "ecr_push_document" {
  # 레지스트리 로그인 토큰
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  # spot-* 레포에 push
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [
      "arn:aws:ecr:${var.service_region}:${var.account_id}:repository/spot-*"
    ]
  }
}

# AWS IAM 정책(Policy) 리소스 생성
resource "aws_iam_policy" "ecr_push_policy" {
  name        = "${var.name_prefix}-ecr-push-policy"
  path        = "/"
  description = "${var.git_branch} ECR Push policy"
  policy      = data.aws_iam_policy_document.ecr_push_document.json
}


locals {
  oidc_provider = replace(var.github_oidc_url, "https://", "")
}

# GitHub Actions OIDC Role
resource "aws_iam_role" "github_oidc" {
  name = "${var.name_prefix}-github-oidc-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" : "sts.amazonaws.com",
            "${local.oidc_provider}:sub" : "repo:first-lounge/Spot:ref:refs/heads/${var.git_branch}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-github-oidc-role" })
}

# IAM Role에게 정책 연결
resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_oidc.name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}
