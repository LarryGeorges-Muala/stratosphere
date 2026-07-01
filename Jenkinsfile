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
                            trivy fs /app --include-dev-deps --dependency-tree
                        '''
                    }
                }
            }
        }
        stage('SBOM - Syft/Grype') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            curl -sSfL https://get.anchore.io/syft | sh -s -- -b /usr/local/bin
                            curl -sSfL https://get.anchore.io/grype | sh -s -- -b /usr/local/bin
                            rm -rf /scans || true
                            mkdir /scans
                            syft /app -o cyclonedx-json=/scans/sbom.json
                            grype sbom:/scans/sbom.json
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / hashicorp') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/hashicorp" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / 0xdea') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/0xdea" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / akabe1') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/akabe1" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / atlassian-labs') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/atlassian-labs" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / community') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/community" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / decurity') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/decurity" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / dgryski') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/dgryski" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / dotta') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/dotta" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / elttam') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/elttam" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / kondukto') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/kondukto" --metrics=off --dataflow-traces --debug
                            deactivate
                        '''
                    }
                }
            }
        }
        stage('SAST / Semgrep / trailofbits') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    retry(2) {
                        sh '''
                            apt update && apt install -y gnupg curl wget unzip ca-certificates
                            apt install python3 -y
                            apt install python3-pip -y
                            apt install python3-venv -y
                            python3 -m venv ./.venv
                            . ./.venv/bin/activate
                            python3 -m pip install semgrep
                            export SEMGREP_SEND_METRICS=off
                            python3 -m pip install semgrep-rules-manager
                            mkdir -p $HOME/custom-semgrep-rules
                            semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
                            ls $HOME/custom-semgrep-rules
                            cd /app
                            semgrep --config="$HOME/custom-semgrep-rules/trailofbits" --metrics=off --dataflow-traces --debug
                            deactivate
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
