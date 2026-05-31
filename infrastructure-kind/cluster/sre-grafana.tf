###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kubectl get svc -n staging
### kubectl get daemonsets -n staging
### kubectl describe daemonset/grafana-monitoring -n staging
######
### kubectl get events -n staging
### kubectl port-forward svc/grafana-monitoring-api -n staging 3000:3000
### kubectl exec grafana-monitoring-fxcc4 -n staging -it -- /bin/sh
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

resource "kubernetes_secret" "grafana_config" {
  depends_on = [
    helm_release.alertmanager
  ]
  metadata {
    name      = "grafana-config"
    namespace = "staging"
  }
  data = {
    "sample-django-alert-resource.yaml"  = "${file("../../monitoring/grafana/alerting/sample-django-alert-resource.yaml")}"
    "sample-django-alert.yaml"           = "${file("../../monitoring/grafana/alerting/sample-django-alert.yaml")}"
    "sample-django-host-alert.yaml"      = "${file("../../monitoring/grafana/alerting/sample-django-host-alert.yaml")}"
    "dashboards.yml"                     = "${file("../../monitoring/grafana/dashboards/dashboards.yml")}"
    "django-host-metrics-dashboard.json" = "${file("../../monitoring/grafana/dashboards/django-host-metrics-dashboard.json")}"
    "django-metrics-dashboard.json"      = "${file("../../monitoring/grafana/dashboards/django-metrics-dashboard.json")}"
    "loki-datasource.yaml"               = "${file("../../monitoring/grafana/datasources/loki-datasource.yaml")}"
    "prometheus-datasource.yaml"         = "${file("../../monitoring/grafana/datasources/prometheus-datasource.yaml")}"
    "tempo-datasource.yaml"              = "${file("../../monitoring/grafana/datasources/tempo-datasource.yaml")}"
  }
  type = "generic"
}

################################################################################
# Helm Releases
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release.html
################################################################################

resource "helm_release" "grafana" {
  depends_on = [
    kubernetes_secret.grafana_config
  ]
  name              = "grafana"
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
  values            = [file("${path.module}/helm-values/grafana.yaml")]
}
