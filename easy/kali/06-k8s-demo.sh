#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../.."
pause(){ read -r -p ">>> Take your screenshot, then press Enter to continue..." _; }
echo "== SCALE to 4 =="; kubectl scale deployment notes-app-blue -n notes --replicas=4
sleep 15; kubectl get pods -n notes; pause
kubectl scale deployment notes-app-blue -n notes --replicas=2
echo "== ROLLING UPDATE to 2.0 =="
sed -i 's/>My Notes$/>My Notes v2/' app/templates/base.html
docker build -t notes-app:2.0 .
minikube image load notes-app:2.0
kubectl set image deployment/notes-app-blue notes-app=notes-app:2.0 -n notes
kubectl rollout status deployment/notes-app-blue -n notes
echo "Open the app URL - navbar says 'My Notes v2'"; minikube service notes-app -n notes --url; pause
echo "== ROLLBACK =="
kubectl rollout history deployment/notes-app-blue -n notes
kubectl rollout undo deployment/notes-app-blue -n notes
kubectl rollout status deployment/notes-app-blue -n notes
git checkout app/templates/base.html
echo "Refresh the app - back to 'My Notes'"; pause
echo "== RBAC proof =="
kubectl auth can-i get pods -n notes --as=system:serviceaccount:notes:notes-viewer
kubectl auth can-i delete pods -n notes --as=system:serviceaccount:notes:notes-viewer
