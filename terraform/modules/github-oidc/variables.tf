# 공통
variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "git_branch" {
  description = "Github 브랜치"
  type        = string
}

variable "github_oidc_url" {
  description = "GitHub OIDC 공급자 URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "service_region" {
  description = "ECR 서비스 지역"
  type        = string
}
