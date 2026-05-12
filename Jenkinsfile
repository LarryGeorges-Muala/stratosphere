pipeline {
    agent any
    stages {
        stage('Trivy') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
                            echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | tee -a /etc/apt/sources.list.d/trivy.list
                            apt-get update
                            apt-get install trivy -y
                            trivy fs /app
                        '''
                    }
                }
            }
        }
        stage('Terraform') {
            steps {
                timeout(time: 3, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                            gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
                            apt install lsb-release -y
                            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
                            apt update
                            apt install terraform -y
                            terraform --version
                        '''
                    }
                }
            }
        }
    }
}
