variable "common_tags" { type = map(string) default = {} }
variable "cluster_name" { type = string }

variable "enable_vpc_cni" { type = bool default = true }
variable "enable_coredns" { type = bool default = true }
variable "enable_kube_proxy" { type = bool default = true }
variable "enable_ebs_csi" { type = bool default = true }

variable "vpc_cni_version" { type = string default = "" }
variable "coredns_version" { type = string default = "" }
variable "kube_proxy_version" { type = string default = "" }
variable "ebs_csi_version" { type = string default = "" }

variable "ebs_csi_irsa_role_arn" { type = string default = "" }
