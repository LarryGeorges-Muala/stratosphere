###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get svc -n kube-system
### kubectl get pods -n kube-system
### kubectl get daemonsets -n kube-system
### kubectl describe daemonset/node-monitoring -n kube-system
######
### kubectl get events -n kube-system
### kubectl port-forward svc/node-monitoring-api -n kube-system 9100:9100
### kubectl exec node-monitoring-dwkdn -n kube-system -it -- /bin/sh
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

resource "helm_release" "node" {
  depends_on = [
    helm_release.grafana
  ]
  name              = "node"
  repository        = "https://larrygeorges-muala.github.io/super-chart"
  chart             = "super-chart"
  namespace         = "kube-system"
  create_namespace  = true
  dependency_update = true
  version           = "0.1.6"
  cleanup_on_fail   = true
  upgrade_install   = false
  force_update      = false
  recreate_pods     = false
  atomic            = false
  wait              = false
  lint              = false
  timeout           = 900
  values            = [file("${path.module}/helm-values/node.yaml")]
}
