packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  main_region     = "ap-southeast-1"
  recovery_region = "eu-west-1"

  instance_type       = "t2.micro"
  name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
  root_device_type    = "ebs"
  architecture        = "x86_64"
  virtualization_type = "hvm"
  most_recent         = true
  owners              = "099720109477"
  ssh_username        = "ubuntu"
}

source "amazon-ebs" "ubuntu-main" {
  ami_name      = "${local.main_region}-rancher-golden-ami"
  instance_type = "${local.instance_type}"
  region        = "${local.main_region}"
  source_ami_filter {
    filters = {
      name                = "${local.name}"
      root-device-type    = "${local.root_device_type}"
      architecture        = "${local.architecture}"
      virtualization-type = "${local.virtualization_type}"
    }
    most_recent = local.most_recent
    owners      = ["${local.owners}"]
  }
  ssh_username = "${local.ssh_username}"
}

source "amazon-ebs" "ubuntu-recovery" {
  ami_name      = "${local.recovery_region}-rancher-golden-ami"
  instance_type = "${local.instance_type}"
  region        = "${local.recovery_region}"
  source_ami_filter {
    filters = {
      name                = "${local.name}"
      root-device-type    = "${local.root_device_type}"
      architecture        = "${local.architecture}"
      virtualization-type = "${local.virtualization_type}"
    }
    most_recent = local.most_recent
    owners      = ["${local.owners}"]
  }
  ssh_username = "${local.ssh_username}"
}

build {
  name = "build-rancher-ami"

  sources = [
    "source.amazon-ebs.ubuntu-main",
    "source.amazon-ebs.ubuntu-recovery"
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
