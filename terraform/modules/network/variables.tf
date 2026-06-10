variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}


variable "service_region" {
  description = "AWS 서비스 리전"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "availability_zones" {
  description = "가용 영역"
  type        = map(string)
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 목록"
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 목록"
  type        = map(string)
}

variable "db_subnet_cidrs" {
  description = "DB 서브넷 CIDR 목록"
  type        = map(string)
}

variable "nat_sg_id" {
  description = "NAT Instance SG ID"
  type        = string
}

# 환경별로 값이 변경되는 변수
variable "enable_interface_endpoint" {
  description = "VPC 인터페이스 엔드포인트 활성화 여부"
  type        = bool
}

variable "enable_nat_instance" {
  description = "NAT Instance 활성화 여부"
  type        = bool
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 활성화 여부"
  type        = bool
}
