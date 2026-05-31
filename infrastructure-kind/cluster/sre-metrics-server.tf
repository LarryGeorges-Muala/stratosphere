###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get svc -n staging
### kubectl get daemonsets -n staging
### kubectl describe daemonset/prometheus-monitoring -n staging
######
### kubectl get events -n staging
### kubectl port-forward svc/prometheus-monitoring-api -n staging 9090:9090
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

resource "helm_release" "metrics_server" {
  depends_on = [
    helm_release.rancher
  ]
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = true
  version          = "3.12.1"
  cleanup_on_fail  = true
  upgrade_install  = false
  atomic           = false
  wait             = false
  lint             = false
  timeout          = 900
  values           = [file("${path.module}/helm-values/metrics-server.yaml")]
}
