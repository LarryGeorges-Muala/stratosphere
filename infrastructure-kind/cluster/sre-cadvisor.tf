###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get svc -n staging
### kubectl get daemonsets -n staging
### kubectl describe daemonset/cadvisor-monitoring -n staging
######
### kubectl get events -n staging
### kubectl port-forward svc/cadvisor-monitoring-api -n staging 9090:9090
### kubectl exec cadvisor-monitoring-dwkdn -n staging -it -- /bin/sh
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {

}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "cadvisor" {
  depends_on = [
    helm_release.grafana
  ]
  name              = "cadvisor"
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
  values            = [file("${path.module}/helm-values/cadvisor.yaml")]
}
