locals {
  root_app_path = "${path.root}/../../../k8s/argo/root"
}

module "argocd" {
  source = "../../modules/argocd"

  root_app_path = "${local.root_app_path}/dev.yaml"
}
