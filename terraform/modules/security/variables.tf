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

variable "alb_target_ports" {
  description = "ALB가 트래픽을 spot-gateway, kafka-ui, temporal-ui, grafana, ArgoCD 로 보낼 때 필요한 포트 번호"
  type        = map(number)
  default = {
    "app"     = 8080
    "grafana" = 3000
  }
}
