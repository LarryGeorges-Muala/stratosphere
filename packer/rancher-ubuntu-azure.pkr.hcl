packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "main_client_id" {
  type    = string
  default = ""
}

variable "recovery_client_id" {
  type    = string
  default = ""
}

variable "main_client_secret" {
  type    = string
  default = ""
}

variable "recovery_client_secret" {
  type    = string
  default = ""
}

variable "main_subscription_id" {
  type    = string
  default = ""
}

variable "recovery_subscription_id" {
  type    = string
  default = ""
}

variable "main_tenant_id" {
  type    = string
  default = ""
}

variable "recovery_tenant_id" {
  type    = string
  default = ""
}

locals {
  main_region     = "southeastasia"
  recovery_region = "westeurope"

  main_client_id     = "${var.main_client_id}"
  recovery_client_id = "${var.recovery_client_id}"

  main_client_secret     = "${var.main_client_secret}"
  recovery_client_secret = "${var.recovery_client_secret}"

  main_subscription_id     = "${var.main_subscription_id}"
  recovery_subscription_id = "${var.recovery_subscription_id}"

  main_tenant_id     = "${var.main_tenant_id}"
  recovery_tenant_id = "${var.recovery_tenant_id}"

  image_publisher = "canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"
  os_type         = "Linux"
  vm_size         = "Standard_DS2_v2"
}

source "azure-arm" "ubuntu-main" {
  client_id                         = "${local.main_client_id}"
  client_secret                     = "${local.main_client_secret}"
  subscription_id                   = "${local.main_subscription_id}"
  tenant_id                         = "${local.main_tenant_id}"
  image_offer                       = "${local.image_offer}"
  image_publisher                   = "${local.image_publisher}"
  image_sku                         = "${local.image_sku}"
  image_version                     = "${local.image_version}"
  location                          = "${local.main_region}"
  managed_image_name                = "${local.main_region}-rancher-golden-ami"
  managed_image_resource_group_name = "${local.main_region}"
  os_type                           = "${local.os_type}"
  vm_size                           = "${local.vm_size}"
}

source "azure-arm" "ubuntu-recovery" {
  client_id                         = "${local.recovery_client_id}"
  client_secret                     = "${local.recovery_client_secret}"
  subscription_id                   = "${local.recovery_subscription_id}"
  tenant_id                         = "${local.recovery_tenant_id}"
  image_offer                       = "${local.image_offer}"
  image_publisher                   = "${local.image_publisher}"
  image_sku                         = "${local.image_sku}"
  image_version                     = "${local.image_version}"
  location                          = "${local.recovery_region}"
  managed_image_name                = "${local.recovery_region}-rancher-golden-ami"
  managed_image_resource_group_name = "${local.recovery_region}"
  os_type                           = "${local.os_type}"
  vm_size                           = "${local.vm_size}"
}

build {
  name = "build-rancher-ami"

  sources = [
    "source.azure-arm.ubuntu-main",
    "source.azure-arm.ubuntu-recovery"
  ]

  provisioner "shell" {
    inline = ["sudo touch startup.log"]
  }

  provisioner "shell" {
    inline = [
      "sudo apt update | sudo tee -a startup.log",
      "sudo apt install ca-certificates curl -y | sudo tee -a startup.log",
      "sudo install -m 0755 -d /etc/apt/keyrings | sudo tee -a startup.log",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc | sudo tee -a startup.log",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc"
    ]
  }

  provisioner "shell" {
    inline = [
      <<OUTER
      sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
      Types: deb
      URIs: https://download.docker.com/linux/ubuntu
      Suites: noble
      Components: stable
      Signed-By: /etc/apt/keyrings/docker.asc
      EOF
    OUTER
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt update | sudo tee -a startup.log",
      "sudo apt install unzip -y | sudo tee -a startup.log",
      "sudo curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
      "sudo unzip awscliv2.zip",
      "sudo ./aws/install",
      "sudo aws --version | sudo tee -a startup.log"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y | sudo tee -a startup.log",
      "sudo systemctl status docker | sudo tee -a startup.log"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt install nfs-common -y | sudo tee -a startup.log",
      "sudo mkdir /rancher | sudo tee -a startup.log",
      "sudo mkdir -p /efs/rancher | sudo tee -a startup.log",
      "sudo chmod go+rw /efs"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo docker run -d --restart=unless-stopped --name rancher --hostname rancher --privileged -p 80:80 -p 443:443 -v /rancher:/var/lib/rancher rancher/rancher:latest | sudo tee -a startup.log"
    ]
  }

  provisioner "shell" {
    inline = [
      "(sudo crontab -l 2>/dev/null; echo \"*/5 * * * * sudo rsync -avu --delete /rancher /efs\") | sudo crontab -",
      "sudo crontab -l | sudo tee -a startup.log"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo docker ps -a | sudo tee -a startup.log"
    ]
  }
}
