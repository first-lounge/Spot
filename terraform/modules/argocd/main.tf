# =============================================================================
# Kubectl Provider 명시
# =============================================================================
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }
}

# =============================================================================
# ArgoCD 설치 & 배포
# =============================================================================
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.15"
  create_namespace = true
  namespace        = "argocd"

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" : true
        }
      }

      server = {
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
            "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
            "alb.ingress.kubernetes.io/group.name"       = "spot-ingress"
            "alb.ingress.kubernetes.io/healthcheck-path" = "/"
            "alb.ingress.kubernetes.io/success-codes"    = "200"
          }
          hostname = "argocd.hbksv.cloud"
        }
      }
    })
  ]

}

# =============================================================================
# Root Application
# =============================================================================
resource "kubectl_manifest" "application" {
  yaml_body = file(var.root_app_path)

  depends_on = [helm_release.argocd]
}
