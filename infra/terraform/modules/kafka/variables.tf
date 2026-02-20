# =============================================================================
# Project Settings
# =============================================================================
variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Network Settings
# =============================================================================
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (SSH 접근용)"
  type        = string
}

variable "subnet_id" {
  description = "Kafka EC2 서브넷 ID (단일 브로커용, deprecated)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Kafka EC2 서브넷 ID 목록 (멀티 브로커용: [private_a, private_c])"
  type        = list(string)
  default     = []
}

variable "broker_count" {
  description = "Kafka 브로커 수 (1 또는 3 권장)"
  type        = number
  default     = 1
}

variable "allowed_security_group_ids" {
  description = "Kafka 접근 허용할 보안그룹 ID 목록"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Public IP 할당 여부"
  type        = bool
  default     = true
}

# =============================================================================
# EC2 Settings
# =============================================================================
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "volume_size" {
  description = "EBS 볼륨 크기 (GB)"
  type        = number
  default     = 20
}

variable "enable_ssh" {
  description = "SSH 접근 허용 여부"
  type        = bool
  default     = false
}

# =============================================================================
# Kafka Settings
# =============================================================================
variable "kafka_version" {
  description = "Kafka 버전"
  type        = string
  default     = "3.7"
}

variable "cluster_id" {
  description = "KRaft 클러스터 ID (고정값 권장)"
  type        = string
  default     = "MkU3OEVBNTcwNTJENDM2Qk"
}

variable "log_retention_hours" {
  description = "메시지 보관 시간"
  type        = number
  default     = 168 # 7일
}

variable "log_retention_gb" {
  description = "로그 최대 크기 (GB)"
  type        = number
  default     = 10
}

# =============================================================================
# DNS Settings
# =============================================================================
variable "create_private_dns" {
  description = "Private DNS Zone 생성 여부"
  type        = bool
  default     = false
}


variable "delete_on_termination" {
  type    = bool
  default = true
}