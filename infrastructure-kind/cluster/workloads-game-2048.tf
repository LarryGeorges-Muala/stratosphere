###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### helm package ./game-2048 --destination ./game-2048/charts
### helm lint --strict ./game-2048/charts/game-2048-0.1.0.tgz
######
### kubectl port-forward svc/game-2048-backend-api -n staging 8081:80
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

resource "helm_release" "game_2048" {
  depends_on = [
    helm_release.rancher
  ]
  name             = "game-2048"
  chart            = "../charts/game-2048/charts/game-2048-0.1.0.tgz"
  namespace        = "staging"
  create_namespace = true
  version          = "0.1.0"
  cleanup_on_fail  = true
  reuse_values     = false
  upgrade_install  = false
  atomic           = false
  wait             = false
  lint             = true
  recreate_pods    = false
  timeout          = 600

  set = [
    {
      name  = "super-chart.replicaCount"
      value = 1
    },
    {
      name  = "super-chart.autoscaling.minReplicas"
      value = 1
    },
    {
      name  = "super-chart.autoscaling.maxReplicas"
      value = 10
    },
    {
      name  = "super-chart.autoscaling.targetCPUUtilizationPercentage"
      value = 200
    },
    {
      name  = "super-chart.autoscaling.targetMemoryUtilizationPercentage"
      value = 200
    },
    {
      name  = "super-chart.service.scheme"
      value = "internal"
    },
    {
      name  = "super-chart.service.type"
      value = "ClusterIP"
    },
    {
      name  = "super-chart.targetGroupBinding.enabled"
      value = false
    },
    {
      name  = "super-chart.targetGroupBinding.arn"
      value = ""
    },
    {
      name  = "super-chart.targetGroupBinding.securityGroup"
      value = ""
    },
    {
      name  = "super-chart.namespace"
      value = "staging"
    }
  ]
}
