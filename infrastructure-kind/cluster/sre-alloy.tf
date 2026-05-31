###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get svc -n staging
### kubectl get daemonsets -n staging
### kubectl describe daemonset/alloy-monitoring -n staging
######
### kubectl get events -n staging
### kubectl port-forward svc/alloy-monitoring-api -n staging 12345:12345
### kubectl exec alloy-monitoring-dwkdn -n staging -it -- /bin/sh
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {

}

################################################################################
# Kubernetes Secrets
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret.html
################################################################################

resource "kubernetes_secret" "alloy_config" {
  depends_on = [
    helm_release.loki
  ]
  metadata {
    name      = "alloy-config"
    namespace = "staging"
  }
  data = {
    "config.alloy" = "${file("../../monitoring/alloy/config/config.alloy")}"
  }
  type = "generic"
}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "alloy" {
  depends_on = [
    kubernetes_secret.alloy_config
  ]
  name              = "alloy"
  repository        = "https://larrygeorges-muala.github.io/super-chart"
  chart             = "super-chart"
  namespace         = "staging"
  create_namespace  = true
  dependency_update = true
  version           = "0.1.5"
  cleanup_on_fail   = true
  upgrade_install   = false
  force_update      = false
  recreate_pods     = false
  atomic            = false
  wait              = false
  lint              = false
  timeout           = 900
  values            = [file("${path.module}/helm-values/alloy.yaml")]
}
