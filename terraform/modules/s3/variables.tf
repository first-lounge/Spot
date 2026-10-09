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

variable "region" {
  description = "AWS 리전"
  type        = string
}

variable "enable_versioning" {
  description = "Bucket 버저닝 활성화 여부"
  type        = bool
  default     = false # Dev: 비활성화 / Prod: true
}

variable "s3_log_expiration_days" {
  description = "로그 만료 기간 (일)"
  type        = number
  default     = 7 # Dev, Prod 모두
}

# # 운영 전환 시
# variable "s3_log_transition_days" {
#   description = "로그를 Glacier로 이동하는 일수"
#   type        = number
#   default     = 30
# }
