###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get pods -n argocd
### kubectl get deployments -n argocd
### kubectl get events -n argocd
### kubectl create namespace argocd
### kubectl delete namespace argocd
### kubectl port-forward svc/argocd-server -n argocd 8080:443
### kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {

}

################################################################################
# Helm Releases / Argo CD
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "argo_cd" {
  depends_on = [
    null_resource.namespaces_completed
  ]
  name              = "argocd"
  repository        = "https://argoproj.github.io/argo-helm"
  chart             = "argo-cd"
  namespace         = "argocd"
  create_namespace  = true
  dependency_update = true
  version           = "9.5.17"
  cleanup_on_fail   = true
  upgrade_install   = false
  force_update      = false
  recreate_pods     = false
  atomic            = false
  wait              = false
  lint              = false
  timeout           = 1200
}
