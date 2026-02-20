# -----------------------------------------------------------------------------
# (A) ArgoCD Remote Access (namespace/sa/crb)
# -----------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "argocd" {
  count = var.enable_argocd_access ? 1 : 0

  metadata {
    name = "argocd"
  }
}

resource "kubernetes_service_account_v1" "argocd_manager" {
  count = var.enable_argocd_access ? 1 : 0

  metadata {
    name      = "argocd-manager"
    namespace = kubernetes_namespace_v1.argocd[0].metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "argocd_manager_admin" {
  count = var.enable_argocd_access ? 1 : 0

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
    name      = kubernetes_service_account_v1.argocd_manager[0].metadata[0].name
    namespace = kubernetes_service_account_v1.argocd_manager[0].metadata[0].namespace
  }
}

# -----------------------------------------------------------------------------
# (B) AWS Load Balancer Controller (Helm)
# -----------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  count      = var.enable_lbc ? 1 : 0
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  # IRSA에서 SA를 만들고 role-arn annotation 붙일 거면 false 유지
  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}




# irsa - SA 생성
locals {
  k8s_sas = {
    for k, v in var.service_accounts : k => v
    if try(v.create_k8s_sa, true)
  }

  namespaces = toset([
    for k, v in local.k8s_sas : v.namespace
    if v.namespace != "kube-system" && v.namespace != "default"
  ])
}

resource "kubernetes_namespace_v1" "this" {
  for_each = local.namespaces

  metadata {
    name = each.value
  }
}

resource "kubernetes_service_account_v1" "this" {
  for_each = {
    for k, v in local.k8s_sas : k => v
    if try(v.create_k8s_sa, true)
  }

  metadata {
    name      = each.value.service_account
    namespace = each.value.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = var.service_account_role_arns[each.key]
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}
