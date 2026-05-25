packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

locals {
  main_region     = "asia-southeast1"
  recovery_region = "europe-west1"
  project_id      = "stratosphere-497017"
  source_image    = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
  ssh_username    = "ubuntu"
}

source "googlecompute" "ubuntu-main" {
  project_id   = "${local.project_id}"
  source_image = "${local.source_image}"
  ssh_username = "${local.ssh_username}"
  image_name   = "${local.main_region}-rancher-golden-ami"
  zone         = "${local.main_region}"
}

source "googlecompute" "ubuntu-recovery" {
  project_id   = "${local.project_id}"
  source_image = "${local.source_image}"
  ssh_username = "${local.ssh_username}"
  image_name   = "${local.recovery_region}-rancher-golden-ami"
  zone         = "${local.recovery_region}"
}

build {
  name = "build-rancher-ami"

  sources = [
    "source.googlecompute.ubuntu-main",
    "source.googlecompute.ubuntu-recovery"
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
