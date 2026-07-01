###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {

}

################################################################################
# Kubernetes Namespaces - DevOps
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "devops" {
  depends_on = [
    kind_cluster.default
  ]
  metadata {
    annotations = {
      name = "devops"
    }

    labels = {
      type      = "workloads"
      category  = "devops"
      namespace = "devops"
    }

    name = "devops"
  }
}

################################################################################
# Kubernetes Namespaces - Staging
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "staging" {
  depends_on = [
    kubernetes_namespace_v1.devops
  ]
  metadata {
    annotations = {
      name = "staging"
    }

    labels = {
      type      = "workloads"
      category  = "applications"
      namespace = "staging"
    }

    name = "staging"
  }
}

################################################################################
# Kubernetes Namespaces - Prod
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "production" {
  depends_on = [
    kubernetes_namespace_v1.staging
  ]
  metadata {
    annotations = {
      name = "production"
    }

    labels = {
      type      = "workloads"
      category  = "applications"
      namespace = "production"
    }

    name = "production"
  }
}

################################################################################
# Kubernetes Namespaces - Argo CD
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "argocd" {
  depends_on = [
    kubernetes_namespace_v1.production
  ]
  metadata {
    annotations = {
      name = "argocd"
    }

    labels = {
      type      = "workloads"
      category  = "system"
      namespace = "argocd"
    }

    name = "argocd"
  }
}

################################################################################
# Kubernetes Namespaces - Jenkins CI
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "jenkins" {
  depends_on = [
    kubernetes_namespace_v1.argocd
  ]
  metadata {
    annotations = {
      name = "jenkins"
    }

    labels = {
      type      = "workloads"
      category  = "system"
      namespace = "jenkins"
    }

    name = "jenkins"
  }
}

################################################################################
# Kubernetes Namespaces - Rancher / Cert Manager
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "cert_manager" {
  depends_on = [
    kubernetes_namespace_v1.jenkins
  ]
  metadata {
    annotations = {
      name = "cert-manager"
    }

    labels = {
      type      = "workloads"
      category  = "system"
      namespace = "cert-manager"
    }

    name = "cert-manager"
  }
}

################################################################################
# Kubernetes Namespaces - Rancher / Cattle System
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
################################################################################

resource "kubernetes_namespace_v1" "cattle_system" {
  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]
  metadata {
    annotations = {
      name = "cattle-system"
    }

    labels = {
      type      = "workloads"
      category  = "system"
      namespace = "cattle-system"
    }

    name = "cattle-system"
  }
}

################################################################################
# Kubernetes Namespaces - Null Resource
# https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource
################################################################################

resource "null_resource" "namespaces_completed" {
  depends_on = [
    kubernetes_namespace_v1.cattle_system
  ]
}
