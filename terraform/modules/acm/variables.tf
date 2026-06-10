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

variable "zone_id" {
  type        = string
  description = "Route53 Zone ID (ACM DNS 검증용)"
}
