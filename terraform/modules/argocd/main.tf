# =============================================================================
# ArgoCD 배포
# =============================================================================
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.15"
  create_namespace = true
  namespace        = "argocd"
  values           = [file("${var.values_path}/argocd.yaml")]
}

# =============================================================================
# Root Application
# =============================================================================
resource "helm_release" "root_app" {
  name       = "root-app"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"
  namespace  = "argocd"
  values     = [file("${var.values_path}/root-app.yaml")]

  depends_on = [helm_release.argocd]
}
