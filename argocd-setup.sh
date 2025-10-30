#!/bin/bash
# ==========================================================
# 📘 Chapter 1: ArgoCD Installation on Kind Cluster
# Author: Your Name
# Description: Installs Docker, Kind, Kubectl, Helm, and Argo CD
# ==========================================================

set -e  # Exit immediately if a command exits with a non-zero status

# -------------------------------
# Chapter 1: System Update & Docker Installation
# -------------------------------
echo "📦 [Chapter 1] Updating system and installing Docker..."
sudo apt-get update -y
sudo apt-get install -y docker.io

echo "⚙️  Adding current user to Docker group..."
sudo usermod -aG docker "$USER"
newgrp docker

echo "🐳 Docker version:"
docker --version
docker ps || true

# -------------------------------
# Chapter 2: Kind Cluster Installation
# -------------------------------
echo "🌱 [Chapter 2] Installing Kind (Kubernetes in Docker)..."
if [ "$(uname -m)" = "x86_64" ]; then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
else
  echo "⚠️ Unsupported architecture: $(uname -m)"
  exit 1
fi

chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
echo "✅ Kind installed successfully."

# -------------------------------
# Chapter 3: Kubectl Installation
# -------------------------------
echo "🔧 [Chapter 3] Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
chmod +x kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl

echo "✅ Kubectl version:"
kubectl version --client

# -------------------------------
# Chapter 4: Helm Installation
# -------------------------------
echo "⛵ [Chapter 4] Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh
echo "✅ Helm installation complete."

# -------------------------------
# Chapter 5: Kind Cluster Creation
# -------------------------------
echo "🏗️  [Chapter 5] Creating Kind cluster..."
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
EOF

kind create cluster --name argocd-cluster --config kind-config.yaml
echo "✅ Kind cluster created successfully."

# -------------------------------
# Chapter 6: Argo CD Installation
# -------------------------------
echo "🚀 [Chapter 6] Installing Argo CD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⌛ Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "✅ Argo CD pods:"
kubectl get pods -n argocd

echo "🌐 Exposing Argo CD server on port 8080..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0 &
sleep 5

echo "🔐 Fetching Argo CD initial admin password..."
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
echo "✅ Save this password for Argo CD login."

# -------------------------------
# Chapter 7: Argo CD CLI Installation
# -------------------------------
echo "🧰 [Chapter 7] Installing Argo CD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

echo "✅ Argo CD CLI version:"
argocd version --client

echo "🎉 Setup complete! Access Argo CD at: https://localhost:8080"
echo "   Login with username: admin"
echo "   Password: (see above)"
