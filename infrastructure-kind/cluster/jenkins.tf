###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get svc -n jenkins
### kubectl get daemonsets -n jenkins
### kubectl describe daemonset/jenkins-ci -n jenkins
######
### kubectl get events -n jenkins
### kubectl port-forward svc/jenkins-ci-api -n jenkins 8080:8080
### kubectl exec jenkins-ci-6tgtr -n jenkins -it -- /bin/sh
### kubectl exec jenkins-ci-6tgtr -c jenkins-ci-dind -n jenkins -it -- /bin/sh
### cat /var/jenkins_home/secrets/initialAdminPassword
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

resource "kubernetes_secret" "jenkins_config" {
  depends_on = [
    helm_release.argo_cd
  ]
  metadata {
    name      = "jenkins-config"
    namespace = "jenkins"
  }
  data = {
    "plugins.txt" = "${file("../../jenkins.plugins.txt")}"
  }
  type = "generic"
}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "jenkins" {
  depends_on = [
    kubernetes_secret.jenkins_config
  ]
  name              = "jenkins"
  repository        = "https://larrygeorges-muala.github.io/super-chart"
  chart             = "super-chart"
  namespace         = "jenkins"
  create_namespace  = true
  dependency_update = true
  version           = "0.1.5"
  cleanup_on_fail   = true
  upgrade_install   = true
  force_update      = false
  recreate_pods     = false
  atomic            = false
  wait              = false
  lint              = false
  timeout           = 900
  values            = [file("${path.module}/helm-values/jenkins.yaml")]
}
