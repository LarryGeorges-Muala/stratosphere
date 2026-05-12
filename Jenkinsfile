/* Requires the Docker Pipeline plugin */
pipeline {
    agent { docker { image 'ubuntu:24.04' } }
    stages {
        stage('Cleanup') {
            steps {
                // Deletes the workspace before the main build logic
                cleanWs()
            }
        }
        stage('build') {
            steps {
                sh 'python --version'
            }
        }
    }
}