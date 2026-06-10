# 공통
variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "services_name" {
  description = "SPOT 서비스 이름 목록"
  type        = set(string)
}

variable "image_retention_count" {
  description = "유지할 이미지 수"
  type        = number
  default     = 5
}
