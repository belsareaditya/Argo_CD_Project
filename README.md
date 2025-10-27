# Argocd Kubernetes Gitops Tutorial


## Install ArgoCD on your Cluster
```
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd
```

## Access ArgoCD UI

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Retrieve Credentials

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
```
## For Windows Powershell Conversion
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | % { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

To verify, you can get all grades with:
```bash
curl http://localhost:<port>/grades
```
Install the Values.yaml to get Svc install for Monitoring.
helm upgrade --install argocd argo/argo-cd -n argocd -f .\values_svc.yaml



