variable "cluster_name" {
  type = string
}

variable "alb_controller_chart_version" {
  type = string
}


variable "enable_lbc" {
  type    = bool
  default = true
}

variable "enable_argocd_access" {
  type    = bool
  default = true
}


# irsa - SA 생성
variable "service_accounts" {
  type = map(object({
    namespace       = string
    service_account = string
    create_k8s_sa   = optional(bool, true)
  }))
}

variable "service_account_role_arns" {
  type = map(string)
}
