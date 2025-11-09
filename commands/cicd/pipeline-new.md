---
description: Create production-ready CI/CD pipeline with best practices
---

# CI/CD Pipeline Creation Command

You are helping create a production-ready CI/CD pipeline with security, testing, and deployment automation best practices.

## Requirements

**User must provide:**
- CI/CD platform (GitHub Actions, GitLab CI, Jenkins, CircleCI, Azure DevOps)
- Application type (web app, API, microservice, container, etc.)
- Target deployment environment (Kubernetes, AWS, GCP, Azure, serverless)
- Required stages (build, test, deploy, etc.)

**Prerequisites:**
- Repository access and permissions
- Cloud provider credentials (if deploying to cloud)
- Container registry access (if using containers)
- Deployment target configured

## Pipeline Design Workflow

### 1. Pipeline Architecture

**Standard Pipeline Stages:**

```
Code Push → Validate → Build → Test → Security Scan → Package → Deploy → Verify
```

**Recommended stages:**

1. **Validation** - Linting, formatting, dependency checks
2. **Build** - Compile code, build artifacts/containers
3. **Test** - Unit, integration, end-to-end tests
4. **Security** - Vulnerability scanning, secret detection, SAST
5. **Package** - Create deployable artifacts, push containers
6. **Deploy** - Deploy to environments (dev → staging → production)
7. **Verify** - Post-deployment smoke tests, health checks
8. **Rollback** - Automated rollback on failure

### 2. GitHub Actions Pipeline

**File:** `.github/workflows/ci-cd.yml`

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:  # Manual trigger

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Stage 1: Validation
  validate:
    name: Code Validation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js  # Adjust for your language
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint code
        run: npm run lint

      - name: Check formatting
        run: npm run format:check

      - name: Dependency audit
        run: npm audit --audit-level=moderate

  # Stage 2: Build
  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup build environment
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build application
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: dist/
          retention-days: 7

  # Stage 3: Test
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: build
    strategy:
      matrix:
        test-suite: [unit, integration, e2e]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup test environment
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run ${{ matrix.test-suite }} tests
        run: npm run test:${{ matrix.test-suite }}

      - name: Upload test coverage
        uses: codecov/codecov-action@v4
        if: matrix.test-suite == 'unit'
        with:
          file: ./coverage/coverage.xml
          fail_ci_if_error: true

  # Stage 4: Security Scanning
  security:
    name: Security Scans
    runs-on: ubuntu-latest
    needs: build
    permissions:
      security-events: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Secret scanning
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD

  # Stage 5: Build and Push Container
  container:
    name: Build & Push Container
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.event_name != 'pull_request'
    permissions:
      contents: read
      packages: write
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64,linux/arm64

      - name: Scan container image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.meta.outputs.tags }}
          format: 'sarif'
          output: 'container-scan.sarif'

  # Stage 6: Deploy to Staging
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: container
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG_STAGING }}

      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/myapp \
            myapp=${{ needs.container.outputs.image-tag }} \
            -n staging
          kubectl rollout status deployment/myapp -n staging

      - name: Run smoke tests
        run: |
          npm run test:smoke -- --env=staging

  # Stage 7: Deploy to Production
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://app.example.com
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG_PRODUCTION }}

      - name: Create backup
        run: |
          kubectl get deployment/myapp -n production -o yaml > backup-deployment.yaml

      - name: Deploy to Kubernetes (Blue/Green)
        run: |
          # Deploy new version as "green"
          kubectl apply -f k8s/deployment-green.yaml
          kubectl rollout status deployment/myapp-green -n production

          # Run health checks
          kubectl wait --for=condition=available --timeout=300s \
            deployment/myapp-green -n production

          # Switch traffic
          kubectl patch service myapp -n production \
            -p '{"spec":{"selector":{"version":"green"}}}'

          # Monitor for issues
          sleep 60

          # If healthy, scale down blue
          kubectl scale deployment/myapp-blue -n production --replicas=0

      - name: Run production smoke tests
        run: |
          npm run test:smoke -- --env=production

      - name: Rollback on failure
        if: failure()
        run: |
          # Switch traffic back to blue
          kubectl patch service myapp -n production \
            -p '{"spec":{"selector":{"version":"blue"}}}'

          # Scale blue back up
          kubectl scale deployment/myapp-blue -n production --replicas=3

          # Remove green
          kubectl delete deployment/myapp-green -n production

  # Stage 8: Notify
  notify:
    name: Notify Team
    runs-on: ubuntu-latest
    needs: [deploy-production]
    if: always()
    steps:
      - name: Send Slack notification
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployment ${{ job.status }}: ${{ github.repository }}@${{ github.sha }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Deployment Status:* ${{ job.status }}\n*Repository:* ${{ github.repository }}\n*Branch:* ${{ github.ref_name }}\n*Commit:* ${{ github.sha }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 3. GitLab CI Pipeline

**File:** `.gitlab-ci.yml`

```yaml
stages:
  - validate
  - build
  - test
  - security
  - package
  - deploy-staging
  - deploy-production

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  DOCKER_IMAGE: $DOCKER_REGISTRY/$CI_PROJECT_PATH
  KUBERNETES_VERSION: "1.28"

# Validation Stage
lint:
  stage: validate
  image: node:20-alpine
  cache:
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run lint
    - npm run format:check
  only:
    - merge_requests
    - main
    - develop

dependency-check:
  stage: validate
  image: node:20-alpine
  script:
    - npm audit --audit-level=moderate
  allow_failure: true

# Build Stage
build:
  stage: build
  image: node:20-alpine
  cache:
    paths:
      - node_modules/
  artifacts:
    paths:
      - dist/
    expire_in: 1 week
  script:
    - npm ci
    - npm run build

# Test Stage
test:unit:
  stage: test
  image: node:20-alpine
  dependencies:
    - build
  script:
    - npm ci
    - npm run test:unit -- --coverage
  coverage: '/All files\s+\|\s+([\d\.]+)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

test:integration:
  stage: test
  image: node:20-alpine
  services:
    - postgres:15
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: testuser
    POSTGRES_PASSWORD: testpass
  script:
    - npm ci
    - npm run test:integration

# Security Stage
sast:
  stage: security
  image: returntocorp/semgrep:latest
  script:
    - semgrep ci --config=auto
  allow_failure: false

container_scanning:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy fs . --severity HIGH,CRITICAL
  allow_failure: false

# Package Stage
docker:build:
  stage: package
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $DOCKER_IMAGE:$CI_COMMIT_SHA .
    - docker tag $DOCKER_IMAGE:$CI_COMMIT_SHA $DOCKER_IMAGE:latest
    - docker push $DOCKER_IMAGE:$CI_COMMIT_SHA
    - docker push $DOCKER_IMAGE:latest
    - trivy image $DOCKER_IMAGE:$CI_COMMIT_SHA
  only:
    - main
    - develop

# Deploy Staging
deploy:staging:
  stage: deploy-staging
  image: bitnami/kubectl:$KUBERNETES_VERSION
  environment:
    name: staging
    url: https://staging.example.com
  before_script:
    - kubectl config use-context staging
  script:
    - kubectl set image deployment/myapp myapp=$DOCKER_IMAGE:$CI_COMMIT_SHA -n staging
    - kubectl rollout status deployment/myapp -n staging --timeout=5m
  only:
    - main

# Deploy Production
deploy:production:
  stage: deploy-production
  image: bitnami/kubectl:$KUBERNETES_VERSION
  environment:
    name: production
    url: https://app.example.com
  when: manual  # Require manual approval
  before_script:
    - kubectl config use-context production
  script:
    - kubectl set image deployment/myapp myapp=$DOCKER_IMAGE:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/myapp -n production --timeout=10m
    - kubectl wait --for=condition=available --timeout=300s deployment/myapp -n production
  only:
    - main
```

### 4. Jenkins Pipeline

**File:** `Jenkinsfile`

```groovy
pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'your-registry.azurecr.io'
        IMAGE_NAME = 'myapp'
        KUBERNETES_NAMESPACE = 'default'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate') {
            parallel {
                stage('Lint') {
                    steps {
                        sh 'npm ci'
                        sh 'npm run lint'
                    }
                }
                stage('Security Scan') {
                    steps {
                        sh 'npm audit --audit-level=moderate'
                    }
                }
            }
        }

        stage('Build') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
        }

        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'npm run test:unit'
                    }
                    post {
                        always {
                            junit 'test-results/unit/*.xml'
                        }
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh 'npm run test:integration'
                    }
                }
            }
        }

        stage('Build Container') {
            when {
                branch 'main'
            }
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'azure-credentials') {
                        def image = docker.build("${IMAGE_NAME}:${BUILD_NUMBER}")
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                withKubeConfig([credentialsId: 'kubeconfig-staging']) {
                    sh """
                        kubectl set image deployment/${IMAGE_NAME} \
                            ${IMAGE_NAME}=${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
                            -n staging
                        kubectl rollout status deployment/${IMAGE_NAME} -n staging
                    """
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
                ok "Deploy"
            }
            steps {
                withKubeConfig([credentialsId: 'kubeconfig-production']) {
                    sh """
                        kubectl set image deployment/${IMAGE_NAME} \
                            ${IMAGE_NAME}=${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
                            -n production
                        kubectl rollout status deployment/${IMAGE_NAME} -n production
                    """
                }
            }
        }
    }

    post {
        success {
            slackSend(
                color: 'good',
                message: "Pipeline succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "Pipeline failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
    }
}
```

### 5. Pipeline Best Practices

**A. Security:**

- [ ] Secret management via platform secrets (never commit secrets)
- [ ] Vulnerability scanning at multiple stages
- [ ] SAST (Static Application Security Testing)
- [ ] DAST (Dynamic Application Security Testing) for production
- [ ] Container image scanning
- [ ] Dependency scanning
- [ ] Secret detection (TruffleHog, GitGuardian)
- [ ] Signed commits and artifacts
- [ ] Least privilege service accounts

**B. Testing Strategy:**

- [ ] Unit tests (>80% coverage)
- [ ] Integration tests
- [ ] End-to-end tests
- [ ] Smoke tests post-deployment
- [ ] Performance tests
- [ ] Security tests
- [ ] Fail fast on test failures

**C. Deployment:**

- [ ] Separate environments (dev, staging, production)
- [ ] Manual approval for production
- [ ] Blue/green or canary deployments
- [ ] Automated rollback on failure
- [ ] Health checks and readiness probes
- [ ] Deployment verification tests
- [ ] Gradual rollout strategies

**D. Observability:**

- [ ] Pipeline metrics and monitoring
- [ ] Build time tracking
- [ ] Failure rate monitoring
- [ ] Deployment frequency tracking
- [ ] Detailed logs for debugging
- [ ] Artifact retention policies
- [ ] Audit trails

**E. Performance:**

- [ ] Caching (dependencies, build layers)
- [ ] Parallel execution where possible
- [ ] Optimized Docker builds (multi-stage)
- [ ] Minimal base images
- [ ] Build artifact reuse
- [ ] Incremental builds

## Best Practices

**Pipeline as Code:**
- Version control all pipeline definitions
- Use reusable workflows/templates
- Document pipeline stages and requirements
- Review pipeline changes like code

**Environment Parity:**
- Keep environments as similar as possible
- Use same deployment method across environments
- Infrastructure as Code for consistency
- Environment-specific configurations via variables

**Fail Fast:**
- Run fast checks first (linting, formatting)
- Fail on security issues
- Don't proceed to deployment if tests fail
- Clear error messages for quick debugging

**Notifications:**
- Notify on failures immediately
- Success notifications for production deployments
- Include relevant context (commit, branch, author)
- Multiple channels (Slack, email, PagerDuty)

**Maintenance:**
- Regular dependency updates
- Keep CI/CD platform updated
- Review and optimize slow pipelines
- Clean up old artifacts and caches
- Monitor pipeline costs
