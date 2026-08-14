variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "domain_name" {
  description = "도메인 이름"
  type        = string
}

variable "zone_force_destroy" {
  description = "zone destroy 시 남은 레코드까지 강제 삭제(dev만 true, prod는 false)"
  type        = bool
}
