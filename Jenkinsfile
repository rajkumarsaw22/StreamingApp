pipeline {
    agent any

    environment {
        AWS_REGION = "us-west-1"
        ACCOUNT_ID = "975050024946"
        ECR_BASE = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/batch-14/rajsaw"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build Images') {
            parallel {

                stage('Build Frontend') {
                    steps {
                        sh 'docker build -t frontend:latest -t frontend:${IMAGE_TAG} frontend'
                    }
                }

                stage('Build AuthService') {
                    steps {
                        sh 'docker build -t authservice:latest -t authservice:${IMAGE_TAG} backend/authService'
                    }
                }

                stage('Build StreamingService') {
                    steps {
                        sh 'docker build -f backend/streamingService/Dockerfile -t streamingservice:latest -t streamingservice:${IMAGE_TAG} backend'
                    }
                }

                stage('Build AdminService') {
                    steps {
                        sh 'docker build -f backend/adminService/Dockerfile -t adminservice:latest -t adminservice:${IMAGE_TAG} backend'
                    }
                }

                stage('Build ChatService') {
                    steps {
                        sh 'docker build -f backend/chatService/Dockerfile -t chatservice:latest -t chatservice:${IMAGE_TAG} backend'
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'rajsaw-erc-cred'
                ]]) {
                    sh """
                    set -euo pipefail
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    """
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh """
                set -euo pipefail
                docker tag frontend:latest ${ECR_BASE}/frontend:latest
                docker tag frontend:${IMAGE_TAG} ${ECR_BASE}/frontend:${IMAGE_TAG}
                docker tag authservice:latest ${ECR_BASE}/authservice:latest
                docker tag authservice:${IMAGE_TAG} ${ECR_BASE}/authservice:${IMAGE_TAG}
                docker tag streamingservice:latest ${ECR_BASE}/streamingservice:latest
                docker tag streamingservice:${IMAGE_TAG} ${ECR_BASE}/streamingservice:${IMAGE_TAG}
                docker tag adminservice:latest ${ECR_BASE}/adminservice:latest
                docker tag adminservice:${IMAGE_TAG} ${ECR_BASE}/adminservice:${IMAGE_TAG}
                docker tag chatservice:latest ${ECR_BASE}/chatservice:latest
                docker tag chatservice:${IMAGE_TAG} ${ECR_BASE}/chatservice:${IMAGE_TAG}
                """
            }
        }

        stage('Push Images') {
            steps {
                sh """
                set -euo pipefail
                docker push ${ECR_BASE}/frontend:latest
                docker push ${ECR_BASE}/frontend:${IMAGE_TAG}
                docker push ${ECR_BASE}/authservice:latest
                docker push ${ECR_BASE}/authservice:${IMAGE_TAG}
                docker push ${ECR_BASE}/streamingservice:latest
                docker push ${ECR_BASE}/streamingservice:${IMAGE_TAG}
                docker push ${ECR_BASE}/adminservice:latest
                docker push ${ECR_BASE}/adminservice:${IMAGE_TAG}
                docker push ${ECR_BASE}/chatservice:latest
                docker push ${ECR_BASE}/chatservice:${IMAGE_TAG}
                """
            }
        }
    }

    post {
        success {
            echo "All microservices built & pushed successfully!"
        }
        failure {
            echo "Build failed!"
        }
    }
}
