###############################################################################
######
### TF_LOG=INFO terraform apply -compact-warnings -auto-approve
### TF_LOG=INFO terraform destroy -auto-approve
######
### kind get clusters
### kind delete cluster --name stratosphere
######
### export KUBECONFIG=./config/kube_config
### kubectl config --kubeconfig=./config/kube_config use-context kind-stratosphere
### kubectl get nodes -o wide
### kubectl config use-context kind-stratosphere
### kind delete cluster --name stratosphere
######
###############################################################################

################################################################################
# Locals
################################################################################

locals {
  k8s_config_path = pathexpand("./config/kube_config")
}

################################################################################
# Cluster
# https://registry.terraform.io/providers/tehcyx/kind/latest/docs/resources/cluster
################################################################################

resource "kind_cluster" "default" {
  name            = "stratosphere"
  node_image      = "kindest/node:v1.27.1"
  kubeconfig_path = local.k8s_config_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = 80
      }
    }

    # node {
    #   role = "master"
    # }

    node {
      role = "worker"
    }

    # node {
    #   role = "worker"
    # }

    # node {
    #   role = "worker"
    # }
  }
}
