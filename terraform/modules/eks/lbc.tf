# =============================================================================
# AWS Load Balancer Controller (Helm)
# =============================================================================
resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.3.0"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = local.irsa_roles["lbc"].sa_name
  }

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  dynamic "set" {
    for_each = local.has_etc_group ? [1] : []

    content {
      name  = "nodeSelector.workload"
      value = "etc"
    }
  }

  depends_on = [aws_eks_access_policy_association.master, aws_eks_node_group.this]
}

# =============================================================================
# Service Account (AWS LBC)
# =============================================================================
resource "kubernetes_service_account_v1" "lbc_sa" {
  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa["lbc"].arn
    }
  }

  depends_on = [aws_iam_role.irsa, aws_eks_access_policy_association.master]
}
