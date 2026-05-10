// ============================================================
// NexaCommerce — Jenkins Declarative Pipeline
// Full CI/CD pipeline with parallel stages
// ============================================================

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-agent
  containers:
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: tools
    image: nexacommerce/ci-tools:latest
    command: [cat]
    tty: true
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi
  - name: terraform
    image: hashicorp/terraform:1.7
    command: [cat]
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds(abortPrevious: true)
        timestamps()
    }

    environment {
        REGISTRY         = credentials('ecr-registry')
        AWS_CREDENTIALS  = credentials('aws-ci-credentials')
        SONAR_TOKEN      = credentials('sonarqube-token')
        ARGOCD_TOKEN     = credentials('argocd-token')
        SLACK_WEBHOOK    = credentials('slack-webhook')
        IMAGE_TAG        = "${env.GIT_COMMIT[0..7]}"
        PROJECT          = 'nexacommerce'
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target deployment environment'
        )
        string(
            name: 'SERVICES',
            defaultValue: 'all',
            description: 'Services to build (comma-separated or "all")'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip tests (emergency deploys only)'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Plan only, do not apply'
        )
    }

    stages {
        // ── Checkout & Setup ──────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_BRANCH_NAME = sh(
                        script: 'git rev-parse --abbrev-ref HEAD',
                        returnStdout: true
                    ).trim()
                    env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.IMAGE_TAG}"
                }
                slackSend(
                    channel: '#ci-builds',
                    color: 'good',
                    message: "🔨 Build started: ${env.JOB_NAME} #${env.BUILD_NUMBER} (${env.GIT_BRANCH_NAME})"
                )
            }
        }

        // ── Parallel: Lint & Security Pre-checks ─────────
        stage('Pre-checks') {
            when { expression { !params.SKIP_TESTS } }
            parallel {
                stage('Lint') {
                    steps {
                        container('tools') {
                            sh '''
                                echo "Running linters..."
                                # Go services
                                for svc in auth-service payment-service admin-service; do
                                    if [ -d "backend/$svc" ]; then
                                        cd backend/$svc
                                        golangci-lint run ./... || exit 1
                                        cd ../..
                                    fi
                                done
                                # Java services
                                for svc in product-service order-service; do
                                    if [ -d "backend/$svc" ]; then
                                        cd backend/$svc
                                        mvn checkstyle:check -q || exit 1
                                        cd ../..
                                    fi
                                done
                                echo "Lint passed ✓"
                            '''
                        }
                    }
                }

                stage('Secret Scan') {
                    steps {
                        container('tools') {
                            sh '''
                                gitleaks detect \
                                    --source . \
                                    --report-format json \
                                    --report-path gitleaks-report.json \
                                    --exit-code 1
                            '''
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'gitleaks-report.json',
                                allowEmptyArchive: true
                        }
                    }
                }

                stage('IaC Scan') {
                    steps {
                        container('tools') {
                            sh '''
                                checkov -d terraform/ \
                                    --framework terraform \
                                    --output cli \
                                    --soft-fail
                                checkov -d kubernetes/ \
                                    --framework kubernetes \
                                    --output cli \
                                    --soft-fail
                            '''
                        }
                    }
                }
            }
        }

        // ── Parallel: Unit Tests ──────────────────────────
        stage('Unit Tests') {
            when { expression { !params.SKIP_TESTS } }
            parallel {
                stage('Go Tests') {
                    steps {
                        container('tools') {
                            sh '''
                                for svc in auth-service payment-service admin-service; do
                                    if [ -d "backend/$svc" ]; then
                                        echo "Testing $svc..."
                                        cd backend/$svc
                                        go test ./... -v -race \
                                            -coverprofile=coverage.out \
                                            -covermode=atomic
                                        go tool cover -html=coverage.out \
                                            -o coverage.html
                                        cd ../..
                                    fi
                                done
                            '''
                        }
                    }
                }

                stage('Java Tests') {
                    steps {
                        container('tools') {
                            sh '''
                                for svc in product-service order-service; do
                                    if [ -d "backend/$svc" ]; then
                                        echo "Testing $svc..."
                                        cd backend/$svc
                                        mvn test -q
                                        cd ../..
                                    fi
                                done
                            '''
                        }
                    }
                    post {
                        always {
                            junit '**/target/surefire-reports/*.xml'
                        }
                    }
                }

                stage('Node Tests') {
                    steps {
                        container('tools') {
                            sh '''
                                for svc in cart-service notification-service api-gateway; do
                                    if [ -d "backend/$svc" ]; then
                                        echo "Testing $svc..."
                                        cd backend/$svc
                                        npm ci && npm test -- --coverage --ci
                                        cd ../..
                                    fi
                                done
                                cd frontend && npm ci && npm test -- --coverage --ci
                            '''
                        }
                    }
                }

                stage('Python Tests') {
                    steps {
                        container('tools') {
                            sh '''
                                for svc in inventory-service recommendation-service; do
                                    if [ -d "backend/$svc" ]; then
                                        echo "Testing $svc..."
                                        cd backend/$svc
                                        pip install -r requirements-dev.txt -q
                                        pytest --cov=. --cov-report=xml -v
                                        cd ../..
                                    fi
                                done
                            '''
                        }
                    }
                }
            }
        }

        // ── SonarQube Analysis ────────────────────────────
        stage('SonarQube') {
            when { expression { !params.SKIP_TESTS } }
            steps {
                container('tools') {
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            sonar-scanner \
                                -Dsonar.projectKey=nexacommerce \
                                -Dsonar.sources=. \
                                -Dsonar.exclusions=**/vendor/**,**/node_modules/**,**/.terraform/** \
                                -Dsonar.qualitygate.wait=true
                        '''
                    }
                }
            }
        }

        // ── Build Docker Images ───────────────────────────
        stage('Build Images') {
            steps {
                container('docker') {
                    script {
                        def services = params.SERVICES == 'all'
                            ? ['frontend','auth-service','product-service','cart-service',
                               'order-service','payment-service','inventory-service',
                               'search-service','notification-service']
                            : params.SERVICES.split(',')

                        parallel services.collectEntries { svc ->
                            ["Build ${svc}": {
                                sh """
                                    docker build \
                                        --build-arg GIT_COMMIT=${env.IMAGE_TAG} \
                                        --cache-from ${env.REGISTRY}/${env.PROJECT}/${svc}:latest \
                                        -t ${env.REGISTRY}/${env.PROJECT}/${svc}:${env.IMAGE_TAG} \
                                        -t ${env.REGISTRY}/${env.PROJECT}/${svc}:latest \
                                        backend/${svc}/
                                """
                            }]
                        }
                    }
                }
            }
        }

        // ── Container Security Scan ───────────────────────
        stage('Container Scan') {
            steps {
                container('tools') {
                    sh '''
                        for svc in auth-service product-service payment-service order-service; do
                            echo "Scanning $svc..."
                            trivy image \
                                --exit-code 1 \
                                --severity CRITICAL \
                                --ignore-unfixed \
                                ${REGISTRY}/${PROJECT}/${svc}:${IMAGE_TAG}
                        done
                    '''
                }
            }
        }

        // ── Push Images ───────────────────────────────────
        stage('Push Images') {
            when { expression { !params.DRY_RUN } }
            steps {
                container('docker') {
                    sh '''
                        aws ecr get-login-password --region us-east-1 \
                            | docker login --username AWS --password-stdin ${REGISTRY}

                        for svc in frontend auth-service product-service cart-service \
                                   order-service payment-service inventory-service \
                                   search-service notification-service; do
                            docker push ${REGISTRY}/${PROJECT}/${svc}:${IMAGE_TAG}
                            docker push ${REGISTRY}/${PROJECT}/${svc}:latest
                        done
                    '''
                }
            }
        }

        // ── Deploy ────────────────────────────────────────
        stage('Deploy') {
            when { expression { !params.DRY_RUN } }
            steps {
                container('tools') {
                    script {
                        def env_name = params.ENVIRONMENT
                        sh """
                            argocd login ${ARGOCD_SERVER} \
                                --auth-token ${ARGOCD_TOKEN} \
                                --grpc-web

                            # Update image tags
                            argocd app set nexacommerce-${env_name} \
                                --helm-set global.imageTag=${env.IMAGE_TAG}

                            # Sync application
                            argocd app sync nexacommerce-${env_name} --prune

                            # Wait for health
                            argocd app wait nexacommerce-${env_name} \
                                --health --timeout 300
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ *${env.JOB_NAME}* #${env.BUILD_NUMBER} succeeded\nBranch: ${env.GIT_BRANCH_NAME} | Tag: ${env.IMAGE_TAG}"
            )
        }
        failure {
            slackSend(
                channel: '#alerts-critical',
                color: 'danger',
                message: "❌ *${env.JOB_NAME}* #${env.BUILD_NUMBER} FAILED\nBranch: ${env.GIT_BRANCH_NAME} | <${env.BUILD_URL}|View Build>"
            )
        }
        always {
            cleanWs()
        }
    }
}
