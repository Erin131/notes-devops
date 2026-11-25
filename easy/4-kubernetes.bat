@echo off
cd /d "%~dp0.."
minikube start --memory 4096 --cpus 2
docker compose build
minikube image load notes-app:1.0
kubectl apply -f k8s/app
kubectl rollout status deployment/notes-app-blue -n notes
kubectl get all -n notes
minikube service notes-app -n notes
pause
