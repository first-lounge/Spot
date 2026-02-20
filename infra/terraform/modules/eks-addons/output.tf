output "enabled_addons" {
  value = {
    vpc_cni    = var.enable_vpc_cni
    coredns    = var.enable_coredns
    kube_proxy = var.enable_kube_proxy
    ebs_csi    = var.enable_ebs_csi
  }
}
