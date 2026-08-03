terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  backend "s3" {
    bucket = "spot-tfstate-bucket"
    key    = "dev/terraform.tfstate"
    region = "ap-northeast-2"

    # KMS key로 암호화 활성
    encrypt    = true
    kms_key_id = "arn:aws:kms:ap-northeast-2:164076841262:alias/spot-tfstate"

    dynamodb_table = "spot-tf-locks"
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = local.common_tags
  }
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}
