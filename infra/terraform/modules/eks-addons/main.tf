resource "aws_eks_addon" "vpc_cni" {
  count        = var.enable_vpc_cni ? 1 : 0
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"
  addon_version = var.vpc_cni_version != "" ? var.vpc_cni_version : null

  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "coredns" {
  count        = var.enable_coredns ? 1 : 0
  cluster_name = var.cluster_name
  addon_name   = "coredns"
  addon_version = var.coredns_version != "" ? var.coredns_version : null

  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  count        = var.enable_kube_proxy ? 1 : 0
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"
  addon_version = var.kube_proxy_version != "" ? var.kube_proxy_version : null

  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "ebs_csi" {
  count        = var.enable_ebs_csi ? 1 : 0
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  addon_version = var.ebs_csi_version != "" ? var.ebs_csi_version : null

  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = var.ebs_csi_irsa_role_arn != "" ? var.ebs_csi_irsa_role_arn : null

  tags = var.common_tags
}
