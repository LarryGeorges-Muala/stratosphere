#!/bin/bash

sudo touch startup.log

# Add Docker's official GPG key:
sudo apt update | sudo tee -a startup.log
sudo apt install ca-certificates curl | sudo tee -a startup.log
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

sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

sudo unzip awscliv2.zip

sudo ./aws/install

sudo aws --version | sudo tee -a startup.log

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y | sudo tee -a startup.log

sudo systemctl status docker | sudo tee -a startup.log

sudo apt install nfs-common -y | sudo tee -a startup.log

sudo mkdir /rancher | sudo tee -a startup.log

sudo mkdir -p /efs/rancher | sudo tee -a startup.log

sudo chmod go+rw /efs

sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "${efs}":/ /efs | sudo tee -a startup.log

sudo docker run -d --restart=unless-stopped --name rancher --hostname rancher --privileged -p 80:80 -p 443:443 -v /rancher:/var/lib/rancher rancher/rancher:latest | sudo tee -a startup.log

(sudo crontab -l 2>/dev/null; echo "*/5 * * * * sudo rsync -avu --delete /rancher /efs") | sudo crontab -

sudo crontab -l | sudo tee -a startup.log

sudo docker ps -a | sudo tee -a startup.log

## Confirm user_data on instance
# sudo cat /var/lib/cloud/instance/user-data.txt

## K3s startup logs
# sudo docker cp rancher:/var/lib/rancher/k3s.log .
