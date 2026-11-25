#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
docker compose down || true
if ! command -v kubectl >/dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install kubectl /usr/local/bin/ && rm kubectl
fi
if ! command -v minikube >/dev/null; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
fi
minikube start --driver=docker --memory 3072 --cpus 2
docker compose build
minikube image load notes-app:1.0
kubectl apply -f k8s/app
kubectl rollout status deployment/notes-app-blue -n notes --timeout=180s
kubectl get all -n notes
kubectl get pv,pvc -n notes
echo; echo "APP URL:"; minikube service notes-app -n notes --url
