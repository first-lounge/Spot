# 공통
variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "account_id" {
  description = "AWS 계정 ID"
  type        = string
}
