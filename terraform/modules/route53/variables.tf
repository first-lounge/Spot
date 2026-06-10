variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "domain_name" {
  type        = string
  description = "도메인 이름"
}

variable "environment" {
  description = "환경"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS 이름"
  type        = string
  default     = ""
}
