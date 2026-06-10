# =============================================================================
# S3
# =============================================================================
# state 파일 저장
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name_prefix}-logs"
  force_destroy = true
  tags          = merge(var.common_tags, { Name = "${var.name_prefix}-s3-logs" })
}

# state 파일 실수로 덮어쓰면 복구 불가능
# 버저닝 활성화하면 이전 버전으로 복구 가능
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# S3 퍼블릭 액세스 차단 설정
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 로그 자동 삭제 정책
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }
  }
}

# 로그 버킷 정책 (ALB Access, CloudWatch,)
# 추가 예정 : CloudTrail, RDS
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ALB Access Log
      {
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/alb/AWSLogs/${var.account_id}/*"
      },

      # CloudWatch
      {
        Sid       = "AllowGetBucketAcl",
        Action    = "s3:GetBucketAcl",
        Effect    = "Allow",
        Resource  = aws_s3_bucket.logs.arn,
        Principal = { Service = "logs.${var.region}.amazonaws.com" },
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid       = "AllowPutObject",
        Action    = "s3:PutObject",
        Effect    = "Allow",
        Resource  = "${aws_s3_bucket.logs.arn}/cloudwatch-logs/*",
        Principal = { Service = "logs.${var.region}.amazonaws.com" },
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control",
            "aws:SourceAccount" = var.account_id
          },
        }
      }

      # CloudTrail

      # RDS
    ]
  })
}
