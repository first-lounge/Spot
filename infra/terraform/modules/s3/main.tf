# =============================================================================
# S3 Buckets - 정적 파일 및 로그 저장
# =============================================================================

# -----------------------------------------------------------------------------
# 정적 파일 버킷 (Static Assets)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "static" {
  bucket = "${var.name_prefix}-static-${var.account_id}"

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-static" })
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront OAC 용 버킷 정책 (나중에 CloudFront 추가 시 사용)
resource "aws_s3_bucket_policy" "static" {
  count  = var.cloudfront_oac_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_oac_arn
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 로그 버킷 (Application & Access Logs)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket = "${var.name_prefix}-logs-${var.account_id}"

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-logs" })
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 로그 수명 주기 정책 - 오래된 로그 자동 삭제/이동
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    filter {} # 전체 버킷에 적용

    # 30일 후 Glacier로 이동
    transition {
      days          = var.log_transition_days
      storage_class = "GLACIER"
    }

    # 90일 후 삭제
    expiration {
      days = var.log_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# 로그 버킷 정책 - CloudWatch, CloudTrail, RDS만 허용
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs 내보내기
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/cloudwatch-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid    = "AllowCloudWatchLogsAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      # CloudTrail
      {
        Sid    = "AllowCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${var.account_id}:trail/*"
          }
        }
      },
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/cloudtrail/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${var.account_id}:trail/*"
          }
        }
      },
      # RDS 로그 내보내기 (Enhanced Monitoring, Audit logs)
      {
        Sid    = "AllowRDSLogs"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/rds-logs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      # ALB Access Logs
      {
        Sid    = "AllowALBAccessLogs"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/alb-logs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      }

    ]
  })
}
