resource "helm_release" "aws_load_balancer_controller_spot" {
  provider   = helm
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [module.irsa]
}


# =============================================================================
# argo cd remote 등록
# =============================================================================
resource "kubernetes_namespace_v1" "argocd_access" {
  provider = kubernetes.spot

  metadata {
    name = "argocd"
  }
}

resource "kubernetes_service_account_v1" "argocd_manager" {
  provider = kubernetes.spot

  metadata {
    name      = "argocd-manager"
    namespace = kubernetes_namespace_v1.argocd_access.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "argocd_manager_admin" {
  provider = kubernetes.spot

  metadata {
    name = "argocd-manager-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argocd_manager.metadata[0].name
    namespace = kubernetes_service_account_v1.argocd_manager.metadata[0].namespace
  }
}