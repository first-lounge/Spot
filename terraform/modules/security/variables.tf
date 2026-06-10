variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "enable_nat_instance" {
  description = "NAT Instance 활성화 여부"
  type        = bool
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}
