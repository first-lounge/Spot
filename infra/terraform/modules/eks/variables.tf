variable "name_prefix" { type = string }
variable "common_tags" { type = map(string) default = {} }

variable "cluster_name" { type = string }
variable "cluster_version" { type = string default = "1.29" }

variable "vpc_id" { type = string }

variable "subnet_ids" { type = list(string) }
variable "node_subnet_ids" { type = list(string) }

variable "endpoint_private_access" { type = bool default = true }
variable "endpoint_public_access" { type = bool default = false }
variable "public_access_cidrs" { type = list(string) default = ["0.0.0.0/0"] }

variable "enabled_cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_instance_types" { type = list(string) default = ["t3.medium"] }
variable "node_capacity_type" { type = string default = "ON_DEMAND" }
variable "node_ami_type" { type = string default = "AL2_x86_64" }

variable "node_disk_size" { type = number default = 50 }

variable "node_desired_size" { type = number default = 2 }
variable "node_min_size" { type = number default = 2 }
variable "node_max_size" { type = number default = 4 }

variable "enable_node_ssm" { type = bool default = true }

variable "enable_node_group" {
  description = "Worker Node Group 생성 여부"
  type        = bool
  default     = false
}
