pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  // Runs after every push (webhook) - polling is the fallback when Jenkins is on localhost
  triggers {
    githubPush()
    pollSCM('H/2 * * * *')
  }

  parameters {
    booleanParam(name: 'RUN_SONAR',  defaultValue: false, description: 'Run SonarQube analysis (needs credential "sonar-token")')
    booleanParam(name: 'PUSH_IMAGE', defaultValue: false, description: 'Push image to Docker Hub (needs credential "dockerhub-creds")')
    booleanParam(name: 'UPDATE_GITOPS', defaultValue: false, description: 'Commit the new image tag to Git so ArgoCD deploys it (needs credential "github-creds")')
    string(name: 'DOCKERHUB_USER', defaultValue: 'yourdockerhubuser', description: 'Docker Hub username')
  }

  environment {
    APP_NAME = 'notes-app'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def msg = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
          // Commits made by this pipeline itself must not trigger another build
          env.SKIP_BUILD = msg.contains('[ci skip]') ? 'true' : 'false'
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_SHORT}"
        }
      }
    }

    stage('Build & Test') {
      when { expression { env.SKIP_BUILD != 'true' } }
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --quiet -r app/requirements.txt
          pytest --junitxml=test-results.xml --cov=app --cov-report=xml:coverage.xml --cov-report=term
        '''
      }
      post {
        always { junit allowEmptyResults: true, testResults: 'test-results.xml' }
      }
    }

    stage('SonarQube Analysis') {
      when { expression { env.SKIP_BUILD != 'true' && params.RUN_SONAR } }
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh 'sonar-scanner -Dsonar.host.url=http://sonarqube:9000 -Dsonar.token=$SONAR_TOKEN'
        }
      }
    }

    stage('Docker Build') {
      when { expression { env.SKIP_BUILD != 'true' } }
      steps {
        sh 'docker build -t ${APP_NAME}:${IMAGE_TAG} -t ${APP_NAME}:latest .'
      }
    }

    stage('Image Security Scan (Trivy)') {
      when { expression { env.SKIP_BUILD != 'true' } }
      steps {
        // --exit-code 0 only reports. Change to 1 to FAIL the build on HIGH/CRITICAL findings.
        sh '''
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v trivy-cache:/root/.cache \
            aquasec/trivy:latest image --severity HIGH,CRITICAL --exit-code 0 ${APP_NAME}:${IMAGE_TAG}
        '''
      }
    }

    stage('Package') {
      when { expression { env.SKIP_BUILD != 'true' } }
      steps {
        sh 'docker save ${APP_NAME}:${IMAGE_TAG} | gzip > ${APP_NAME}-${IMAGE_TAG}.tar.gz'
        archiveArtifacts artifacts: '*.tar.gz', fingerprint: true
      }
    }

    stage('Push to Docker Hub') {
      when { expression { env.SKIP_BUILD != 'true' && params.PUSH_IMAGE } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker tag ${APP_NAME}:${IMAGE_TAG} ${DOCKERHUB_USER}/${APP_NAME}:${IMAGE_TAG}
            docker push ${DOCKERHUB_USER}/${APP_NAME}:${IMAGE_TAG}
            docker logout
          '''
        }
      }
    }

    stage('Update GitOps Manifest') {
      when { expression { env.SKIP_BUILD != 'true' && params.PUSH_IMAGE && params.UPDATE_GITOPS } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
          sh '''
            ./scripts/gitops-update.sh ${DOCKERHUB_USER}/${APP_NAME}:${IMAGE_TAG}
            git config user.email "jenkins@local"
            git config user.name "Jenkins"
            git add k8s/app
            git commit -m "ci: deploy ${IMAGE_TAG} to idle colour [ci skip]" || echo "nothing to commit"
            REPO_URL=$(git config --get remote.origin.url | sed "s|https://|https://${GH_USER}:${GH_TOKEN}@|")
            git push "$REPO_URL" HEAD:main
          '''
        }
      }
    }
  }

  post {
    success { echo "Pipeline finished OK - image tag ${env.IMAGE_TAG}" }
    failure { echo 'Pipeline failed - check the stage logs above.' }
    always  { sh 'rm -rf .venv *.tar.gz || true' }
  }
}
