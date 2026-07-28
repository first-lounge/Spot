# 공통
variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
}
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

# EKS Cluster
variable "cluster_role_arn" {
  description = "EKS 클러스터 Role ARN"
  type        = string
}

variable "cluster_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.35"
}

variable "subnet_ids" {
  description = "서브넷 ID 목록"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "VPC 내부에서 항상 접근 가능"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "외부에서도 접근 가능"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "EKS 클러스터로 접근 가능한 IP 목록"
  type        = list(string)
}

variable "admin_role_arn" {
  description = "EKS 접근 가능한 IAM ARN"
  type        = string
}

variable "enabled_cluster_log_types" {
  description = "EKS 컨트롤 플레인 로그 유형"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Node Launch Template
variable "volume_size" {
  description = "EBS 크기"
  type        = number
}

variable "node_group_sg_id" {
  description = "EKS 노드 그룹 보안 그룹 ID"
  type        = string
}

# Node
variable "node_group_role_arn" {
  description = "EKS 노드 그룹 Role ARN"
  type        = string
}

variable "node_subnet_ids" {
  description = "노드그룹 Private 서브넷 ID 목록"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 인스턴스 유형"
  type        = list(string)
}

variable "capacity_type" {
  description = "인스턴스 구매 방식"
  type        = string
}

variable "desired_size" {
  description = "노드 희망 개수"
  type        = number
}

variable "max_size" {
  description = "노드 최대 개수"
  type        = number
}

variable "min_size" {
  description = "노드 최소 개수"
  type        = number
}

# EKS Addons
variable "vpc_cni_version" {
  description = "EKS Addon VPC CNI 버전"
  type        = string
  default     = ""
}

variable "core_dns_version" {
  description = "EKS Addon Core DNS 버전"
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "EKS Addon Kube Proxy 버전"
  type        = string
  default     = ""
}

variable "ebs_csi_version" {
  description = "EKS Addon EBS CSI 버전"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "account_id" {
  description = "AWS 계정 ID"
  type        = string
}

variable "region" {
  description = "AWS 리전"
  type        = string
}
