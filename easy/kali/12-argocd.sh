#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
minikube status >/dev/null 2>&1 || minikube start --driver=docker --memory 3072 --cpus 2
git checkout -- k8s/app
kubectl apply -f k8s/app
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "Waiting for ArgoCD pods (2-4 min)..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=420s
read -r -p "Your GitHub username: " GHUSER
sed -i "s|https://github.com/[^/]*/notes-devops.git|https://github.com/$GHUSER/notes-devops.git|" argocd/application.yaml
git commit -am "Set ArgoCD repo" || true
git push
kubectl apply -f argocd/application.yaml
nohup kubectl port-forward svc/argocd-server -n argocd 8443:443 >/tmp/argocd-pf.log 2>&1 &
sleep 3
echo; echo "ArgoCD URL:  https://localhost:8443   user: admin"
echo -n "Password:    "; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
echo; echo "GitOps demo: edit replicas in k8s/app/10-deployment-blue.yaml, then git commit -am x && git push"
echo "Blue-green via Git: ./scripts/switch-bluegreen.sh green && git commit -am green && git push"
