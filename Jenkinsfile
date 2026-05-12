pipeline {
    agent any
    stages {
        stage('Terraform') {
            steps {
                sh '''
                    echo "Starting env prep for testing..."
                    apt update && apt install -y gnupg software-properties-common curl wget unzip ca-certificates
                    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
                    apt update && apt install terraform -y
                    terraform --version
                '''
            }
        }
    }
}
