variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 목록"
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 목록"
  type        = map(string)
}

variable "availability_zones" {
  description = "가용 영역"
  type        = map(string)
}

variable "nat_instance_type" {
  description = "NAT Instance 타입"
  type        = string
  default     = "t3.nano"
}

# =============================================================================
# NAT Gateway 설정 (Production)
# =============================================================================
variable "use_nat_gateway" {
  description = "NAT Gateway 사용 여부 (false면 NAT Instance)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT Gateway 사용 (비용 절감 vs HA)"
  type        = bool
  default     = true
}

# =============================================================================
# EKS Cluster Name
# =============================================================================
variable "eks_cluster_name" {
  description = "EKS 클러스터 이름 (Subnet tag 용도)"
  type        = string
  default     = "spot-eks"
}
