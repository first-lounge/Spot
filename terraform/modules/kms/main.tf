# =============================================================================
# EBS
# =============================================================================
resource "aws_kms_key" "ebs" {
  description             = "KMS key for spot ebs"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-key-policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow service-linked role use of the customer managed key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:CreateGrant"
        ],
        Resource = "*",
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = true
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ebs-encryption"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.name_prefix}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# =============================================================================
# RDS
# =============================================================================
resource "aws_kms_key" "rds" {
  description             = "KMS key for spot RDS storage and master user secret"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-rds-key-policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  # # 운영 전환 시
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-encryption"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}
