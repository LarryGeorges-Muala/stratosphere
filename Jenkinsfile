pipeline {
    agent any
    stages {
        stage('Terraform') {
            steps {
                sh '''
                    echo "Starting env prep for testing..."
                    terraform --version
                '''
            }
        }
    }
}
