###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get pods -n cert-manager
### kubectl get deployments -n cert-manager
### kubectl get events -n cert-manager
###
### kubectl get pods -n cattle-system
### kubectl get deployments -n cattle-system
### kubectl get events -n cattle-system
###
### kubectl port-forward svc/rancher -n cattle-system 8090:443
### kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
###
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {

}

################################################################################
# Helm Releases / Rancher Cert Manager
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "cert_manager" {
  depends_on = [
    helm_release.jenkins
  ]
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.20.2"
  wait       = true
  timeout    = 1200

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]
}

################################################################################
# Random
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
################################################################################

resource "random_password" "password" {
  depends_on = [
    helm_release.cert_manager
  ]
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

################################################################################
# Helm Releases / Rancher
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "rancher" {
  depends_on = [
    random_password.password
  ]
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  namespace        = "cattle-system"
  create_namespace = false
  wait             = false
  timeout          = 1200
  # version    = "2.14.1" # Update to your target Rancher version

  set = [
    {
      name  = "hostname"
      value = "localhost" # Replace with your valid DNS record
    },
    {
      name  = "bootstrapPassword"
      value = "${random_password.password.result}" # Initial admin password (v2.6+)
    },
    {
      name  = "replicas"
      value = "3"
    },
    {
      name  = "ingress.tls.source"
      value = "cert-manager"
    }
  ]
}
