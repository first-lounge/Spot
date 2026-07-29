terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# state 파일 저장
resource "aws_s3_bucket" "tfstate" {
  bucket = "spot-tfstate-bucket"

  # 버킷에 객체(state 버전 포함)가 남아 있어도 destroy 시 강제 삭제
  force_destroy = true

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "global"
    Project     = "spot"
  }
}

# state 파일 실수로 덮어쓰면 복구 불가능
# 버저닝 활성화하면 이전 버전으로 복구 가능
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17",
    # HTTPS 요청만 허용
    Statement = [
      {
        Sid    = "AllowSSLRequestsOnly",
        Action = "s3:*",
        Effect = "Deny",
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        },
        Principal = "*"
      }
    ]
  })
}

# S3 퍼블릭 액세스 차단 설정
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    blocked_encryption_types = ["SSE-C"]
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "spot-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "global"
    Project     = "spot"
  }
}
