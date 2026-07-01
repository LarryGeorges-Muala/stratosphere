#!/bin/bash

sudo touch startup.log

# Add Docker's official GPG key:
sudo apt update | sudo tee -a startup.log
sudo apt install ca-certificates curl -y | sudo tee -a startup.log
sudo install -m 0755 -d /etc/apt/keyrings | sudo tee -a startup.log
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc | sudo tee -a startup.log
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update | sudo tee -a startup.log

sudo apt install unzip -y | sudo tee -a startup.log

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y | sudo tee -a startup.log

sudo systemctl status docker | sudo tee -a startup.log

sudo apt install nfs-common -y | sudo tee -a startup.log

sudo mkdir /rancher | sudo tee -a startup.log

sudo mkdir -p /efs/rancher | sudo tee -a startup.log

sudo chmod go+rw /efs

sudo docker run -d --restart=unless-stopped --name rancher --hostname rancher --privileged -p 80:80 -p 443:443 -v /rancher:/var/lib/rancher rancher/rancher:latest | sudo tee -a startup.log

(sudo crontab -l 2>/dev/null; echo "*/5 * * * * sudo rsync -avu --delete /rancher /efs") | sudo crontab -

sudo crontab -l | sudo tee -a startup.log

sudo docker ps -a | sudo tee -a startup.log
