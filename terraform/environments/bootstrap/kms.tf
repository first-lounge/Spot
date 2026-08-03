data "aws_caller_identity" "current" {}

resource "aws_kms_key" "tfstate" {
  description             = "KMS key for spot-tfstate-bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "spot-tfstate-key-policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose     = "spot-tfstate-encryption"
    Environment = "Global"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/spot-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}
