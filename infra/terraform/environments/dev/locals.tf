locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  service_accounts = {
    aws_load_balancer_controller = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy_arn      = ""
      create_k8s_sa   = true
    }
    ebs_csi_driver = {
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
      policy_arn      = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      create_k8s_sa   = false
    }
  }
}
