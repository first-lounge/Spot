terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
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

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "--region", "ap-northeast-2", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "--region", "ap-northeast-2", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
