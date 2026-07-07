#!/bin/bash

# STARTUP LOGS
sudo mkdir -p /home/azureuser || true
sudo touch /home/azureuser/startup.log
echo "User: $(whoami)" | sudo tee -a /home/azureuser/startup.log

# UAI
echo "CLIENT_ID: ${CLIENT_ID}" | sudo tee -a /home/azureuser/startup.log
# VAULT NAME
echo "VAULT: ${VAULT}" | sudo tee -a /home/azureuser/startup.log
# GITHUB TOKEN
echo "GITHUB_PAT: ${GITHUB_PAT}" | sudo tee -a /home/azureuser/startup.log
# GITHUB ORG URL
echo "GITHUB_ORG_URL: ${GITHUB_ORG_URL}" | sudo tee -a /home/azureuser/startup.log
# GITHUB ORG
echo "GITHUB_ORG: ${GITHUB_ORG}" | sudo tee -a /home/azureuser/startup.log

# AZURE CLI
sudo curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash
sudo az version | sudo tee -a /home/azureuser/startup.log
az login --identity --client-id ${CLIENT_ID} | sudo tee -a /home/azureuser/startup.log

# RUNNER TOKEN
TOKEN=$(curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GITHUB_PAT}" ${GITHUB_ORG_URL})
RUNNER_TOKEN=$(echo "$TOKEN" | jq -r '.token')

# RUNNER DRIVERS
# Create a folder
mkdir /home/azureuser/actions-runner && cd /home/azureuser/actions-runner
# Download the latest runner package
curl -o actions-runner-linux-x64-2.335.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz
# Optional: Validate the hash
echo "4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf  actions-runner-linux-x64-2.335.1.tar.gz" | shasum -a 256 -c
# Extract the installer
tar xzf ./actions-runner-linux-x64-2.335.1.tar.gz | sudo tee -a /home/azureuser/startup.log
# RUNNER STARTUP
# Cleanup
RUNNER_ALLOW_RUNASROOT="1" ./config.sh remove --token $RUNNER_TOKEN || true
# Add Runner
RUNNER_ALLOW_RUNASROOT="1" ./config.sh --unattended --url https://github.com/${GITHUB_ORG} --token $RUNNER_TOKEN --work "_work" --replace | sudo tee -a /home/azureuser/startup.log
# Start Runner
RUNNER_ALLOW_RUNASROOT="1" ./run.sh | sudo tee -a /home/azureuser/startup.log
