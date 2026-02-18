terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    # postgresql = {
    #   source  = "cyrilgdn/postgresql"
    #   version = "~> 1.21"
    # }
  }

  # 원격 상태 저장소 (팀 협업 시 활성화)
  # backend "s3" {
  #   bucket         = "spot-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-northeast-2"
  #   encrypt        = true
  #   dynamodb_table = "spot-terraform-lock"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# provider "postgresql" {
#   host     = var.db_endpoint
#   username = var.db_username
#   password = var.db_password
#   database = var.db_name
#   sslmode  = "require"
# }

# resource "postgresql_schema" "users" {
#   name  = "users"  # var.services["user"].environment_vars["DB_SCHEMA"] 값과 일치해야 함
#   owner = var.db_username
# }

# kubernetes - IRSA 모듈에 SA 추가
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}

