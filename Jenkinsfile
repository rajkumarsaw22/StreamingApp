pipeline {
    agent any

    environment {
        AWS_REGION = "us-west-1"
        ACCOUNT_ID = "975050024946"
        ECR_BASE = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/batch-14/rajsaw"
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
                        dir('frontend') {
                            sh 'docker build -t frontend .'
                        }
                    }
                }

                stage('Build AuthService') {
                    steps {
                        dir('authService') {
                            sh 'docker build -t authservice .'
                        }
                    }
                }

                stage('Build StreamingService') {
                    steps {
                        dir('streamingService') {
                            sh 'docker build -t streamingservice .'
                        }
                    }
                }

                stage('Build AdminService') {
                    steps {
                        dir('adminService') {
                            sh 'docker build -t adminservice .'
                        }
                    }
                }

                stage('Build ChatService') {
                    steps {
                        dir('chatService') {
                            sh 'docker build -t chatservice .'
                        }
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
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    """
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh """
                docker tag frontend ${ECR_BASE}/frontend:latest
                docker tag authservice ${ECR_BASE}/authservice:latest
                docker tag streamingservice ${ECR_BASE}/streamingservice:latest
                docker tag adminservice ${ECR_BASE}/adminservice:latest
                docker tag chatservice ${ECR_BASE}/chatservice:latest
                """
            }
        }

        stage('Push Images') {
            steps {
                sh """
                docker push ${ECR_BASE}/frontend:latest
                docker push ${ECR_BASE}/authservice:latest
                docker push ${ECR_BASE}/streamingservice:latest
                docker push ${ECR_BASE}/adminservice:latest
                docker push ${ECR_BASE}/chatservice:latest
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