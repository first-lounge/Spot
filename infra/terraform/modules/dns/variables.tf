variable "name_prefix" {
  description = "리소스 네이밍 프리픽스"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "도메인 이름 (ex: spotorder.org)"
  type        = string
}
variable "create_hosted_zone" {
  type    = bool
  default = false
}
# ALB alias record 생성 여부
variable "create_alb_record" {
  description = "ALB(Route53 Alias) 레코드 생성 여부"
  type        = bool
  default     = true
}

variable "alb_record_name" {
  description = "생성할 레코드 이름"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "ALB DNS name (ex: xxx.ap-northeast-2.elb.amazonaws.com)"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB Hosted Zone ID"
  type        = string
  default     = ""
}

variable "associate_to_alb" {
  type    = bool
  default = true
}

variable "alb_name" {
  description = "Ingress가 생성한 ALB 이름 (Ingress annotation load-balancer-name과 동일)"
  type        = string
}
