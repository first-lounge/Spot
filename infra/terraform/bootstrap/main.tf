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
