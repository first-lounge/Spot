variable "name_prefix" {
  type = string
}
variable "common_tags" {
  type = map(string)
  default = {}
}

variable "oidc_issuer_url" {
  type = string
}

variable "service_accounts" {
  type = map(object({
    namespace       = string
    service_account = string
    policy_arn      = optional(string)
  }))
  default = {}
}
