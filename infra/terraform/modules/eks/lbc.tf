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
}

# =============================================================================
# Service Account (AWS LBC + EBS CSI)
# =============================================================================
resource "kubernetes_service_account_v1" "sa" {
  for_each = local.irsa_roles

  metadata {
    name      = each.value.sa_name
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa[each.key].arn
    }
  }

  depends_on = [aws_iam_role.irsa]
}
