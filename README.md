 ArgoCD Setup and Installation

Let's see how we can Setup & Install ArgoCD (UI and CLI) and access via the browser.

---

# Chapter 1 : Prerequisites

Before starting, ensure you have the following installed on your system:

1. **Docker** → Required for Kind to run containers as cluster nodes.

   ```bash
   sudo apt-get update
   sudo apt install docker.io -y
   sudo usermod -aG docker $USER && newgrp docker
   docker --version

   docker ps
   ```

2. **Kind (Kubernetes in Docker)** → To create the cluster.

   ```bash
   kind version
   ```

   [Install Guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

3. **kubectl** → To interact with the cluster.

   ```bash
   kubectl version --client
   ```

   [Install Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

4. **Helm (for Helm-based installation)**

   ```bash
   helm version
   ```

   [Install Guide](https://helm.sh/docs/intro/install/)

---

> [!IMPORTANT]
> 
> You can either follow the below steps or directly run the script [setup_argocd.sh](./setup_argocd.sh)
> 
> The script will create **kind cluster** and **Installs ArgoCD UI and CLI** based on your choice (using HELM or manifest)
> 
> But before using this guide or `setup_argocd.sh`, make sure you replace the `172.31.19.178` address with your EC2 instance private ip in Cluster config for `apiServerAddress`

---

# Chapter 2  : Create Kind Cluster

Save your cluster config as `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "172.31.19.178"   # Change this to your EC2 private IP (run "hostname -I" to check or from your EC2 dashboard)
  apiServerPort: 33893
nodes:
  - role: control-plane
    image: kindest/node:v1.33.1
  - role: worker
    image: kindest/node:v1.33.1
  - role: worker
    image: kindest/node:v1.33.1
```

> Why `apiServerAddress` & `apiServerPort` in kind config?
→ To ensure each kind cluster API server is reachable from the ArgoCD pods. This avoids conflicts (since kind defaults to random localhost ports).

Create the cluster:

```bash
kind create cluster --name argocd-cluster --config kind-config.yaml
```

Verify:

```bash
kubectl cluster-info
kubectl get nodes
```

---

#  Chapter 3 : Install ArgoCD

---

## **Method 2: Install ArgoCD using Official Manifests (kubectl apply)**

(fastest for demos & learning)

### 1. Create namespace

```bash
kubectl create namespace argocd
```

### 2. Apply ArgoCD installation manifest

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3. Verify installation

```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
```

### 4. Expose ArgoCD server

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0 &
```

Access → **[https://<instance_public_ip>:8080](https://<instance_public_ip>:8080)**

### 5. Get initial password

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Login with:

* Username: `admin`
* Password: (above output)

---

# Chapter 4 : Install ArgoCD CLI (Ubuntu/Linux)

ArgoCD server runs inside Kubernetes, but to interact with it from the terminal you need the **ArgoCD CLI (`argocd`)**.  
This is separate from the server installation.

### 1. Install ArgoCD CLI

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### 2. Verify installation

```bash
# Verify installation
argocd version --client
```

### 3. Login to ArgoCD CLI

```bash
argocd login <instance_public_ip>:8080 --username admin --password <initial_password> --insecure
```

> Note: The --insecure flag is required when using port-forward with self-signed TLS certs.
For production, you’d configure proper TLS certs (then --insecure is not needed).

### 4. Get user info

```bash
argocd account get-user-info
```

---

# Chapter 5 : Monitoring ArgoCD

In this chapter, we’ll learn how to **monitor ArgoCD** using **Prometheus, Grafana**. Monitoring gives us visibility into application health, sync performance, and audit trails.

We will monitor two running ArgoCD Applications:

* **online-shop** (declarative demo app)
* **chai-app** (our sample app with notifications)

---

## 1. Why Monitoring Matters

Think of monitoring like a **doctor’s check-up for your apps**:

* **Metrics** → heartbeat, blood pressure (numbers that tell you how ArgoCD is doing)
* **Dashboards** → health reports (visual panels that make it easy to spot problems)

---

## 2. Key Metrics to Watch (Top 5)

ArgoCD exports many Prometheus metrics, but as beginners, focus on these:

1. **Sync status** → `argocd_app_sync_total`

   * Shows how many syncs succeeded/failed.
   * Example: failed syncs of `chai-app`.

2. **Health status** → `argocd_app_info`

   * Tracks if apps are `Healthy`, `Degraded`, or `Missing`.
   * Example: `online-shop` turns Degraded if pods crash.

3. **Reconcile time** → `argocd_app_reconcile`

   * How long ArgoCD takes to compare Git vs cluster.

4. **Git fetch failures** → `argocd_git_fetch_fail_total`

   * Helps debug repo issues (e.g., wrong URL or creds).

5. **API logins** → `argocd_login_request_total`

   * Useful to track user/API activity.

---

## Prerequisites

- Kubernetes cluster (kind, minikube, etc.)
- ArgoCD Server installed & running
- ArgoCD CLI Installed & Logged in
- kubectl configured    
- Helm 3.x installed

> [!IMPORTANT]
> 
> Run this [setup_argocd.sh](../03_setup_installation/setup_argocd.sh) or follow [README.md](../03_setup_installation/README.md), but choose `Manifests` installation method for ArgoCD, because the `metrics` services of ArgoCD will be created by only official manifests, not with helm. Which is requried in monitoring ArgoCD Stuff...

---

# Hands-On: Monitor ArgoCD with Prometheus & Grafana

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ArgoCD Apps   │───▶│   ArgoCD Metrics │───▶│   Prometheus    │
│ (chai-app,      │    │ Endpoints :      │    │   Scrapes       │
│  online-shop)   │    │ 8082, 8083, 8084 │    │   Metrics       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                               ┌─────────────────┐
                                               │    Grafana      │
                                               │ Dashboards      │
                                               │ IDs: 14584,19993│
                                               └─────────────────┘
```

## Step 1: Verify Metrics Endpoints

Run:
```bash
kubectl get svc -n argocd
```

You should see services like `argocd-metrics`, `argocd-server-metrics`, `argocd-repo-server`.

ArgoCD exposes metrics by default, if you installed ArgoCD with Manifests method:

- **Application Controller:** svc/argocd-metrics → 8082/metrics
- **API Server:** svc/argocd-server-metrics → 8083/metrics
- **Repo Server:** svc/argocd-repo-server → 8084/metrics

![argocd-services](output_images/image-1.png)

---

## Step 2: Install Prometheus & Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create namespace monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring
```

> The kube-prometheus-stack is a collection of essential tools for Kubernetes monitoring, bundling everything together for a simpler installation, It installs/deploy `Prometheus`, `Grafana`, `Prometheus Operator`, `Alertmanager`, `Node Exporter`, and `Kube-State-Metrics`.


![kube-prom-stack](output_images/image-2.png)

---

## Step 3: Create ServiceMonitors
We need to tell Prometheus to scrape ArgoCD metrics endpoints. We do this by creating `ServiceMonitor` resources.

Create using: [argocd-service-monitors.yaml](argocd-service-monitors.yaml)

```bash
kubectl apply -f argocd-service-monitors.yaml
```

![service-monitor](output_images/image-3.png)

---

## Step 4: Deploy `chai-app` and `online-shop` Apps

Create: [chai-app.yaml](chai-app.yaml)

Apply: 

```bash
kubectl apply -f chai-app.yaml
```

Then create: [online-shop-app.yaml](online-shop-app.yaml)

Apply:

```bash
kubectl apply -f online-shop-app.yaml
```

> [!NOTE]
>
> Replace `<your-username>` with your GitHub username in both Application CRD, where you have forked & clonned the repo: `argocd-demos`.

* ArgoCD Application Dashboard:
    
    ![argocd-apps](output_images/image-4.png)


* `chai-app`:

    ![chai-app](output_images/image-5.png)

    ![chai-app-working-ui](output_images/image-6.png)


* `online-shop`:

    ![online-shop](output_images/image-7.png)

    ![online-shop-ui](output_images/image-8.png)


---

## Chapter 6 : Access Prometheus Dashboard

Forward Prometheus Service & Opent the inbound rule for port `9090` and access it in browser:

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 --address=0.0.0.0 &
```

## Step 6: Access Grafana Password
```bash
kubectl -n argocd get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```

## Step 5: Access Grafana & Import Dashboards

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 --address=0.0.0.0 &
# Login: admin/prom-operator
```

### Import Dashboards

1. **ArgoCD Overview** (ID: **14584**): Sync & Health metrics
    
    ![argocd-overview-grafana](output_images/image-12.png)

    Similarly, You can scroll down and see all ArgoCD Data.

2. **ArgoCD Operational Overview** (ID: **19993**): Detailed operational metrics

    * Summary & Sync Stats:

        ![argocd-operational](output_images/image-13.png)

    * Repo Server Stats:

        ![repo-server-stats](output_images/image-14.png)

    Similary, You can observe all of your ArgoCD & Cluster Data

---



* Prometheus UI:

    ![prometheus-ui](output_images/image-15.png)

---

## Step 7: Example Queries (Beginner-Friendly)

### Prometheus (PromQL)

Here are some beginner-friendly PromQL queries to monitor ArgoCD:

- **Get All ArgoCD Applications Info**

    Shows application sync status, health status, and labels:

    ```promql
    argocd_app_info
    ```

    ![app_info](output_images/image-17.png)


- **Count Applications by Health Status**
    
    Grouping apps by their health condition:

    ```promql
    count by (health_status) (argocd_app_info)
    ```

    ![healthy-group](output_images/image-18.png)


- **Count Applications by Sync Status**

    Grouping apps by sync status (Synced, OutOfSync, etc.):

    ```promql
    count by (sync_status) (argocd_app_info)
    ```

    ![sync-status](output_images/image-19.png)

- **Application Sync Success / Failure Counts**
    
    Number of syncs per application, broken down by phase:

    ```promql
    sum by (name, phase) (increase(argocd_app_sync_total[5m]))
    ```

    ![app-name-success-failed](output_images/image-20.png)

- **Sync Failures for chai-app:** 
  ```promql
  increase(argocd_app_sync_total{phase="Failed",name="chai-app"}[5m])
  ```

- **Healthy Applications Count:**
  ```promql
  count(argocd_app_info{health_status="Healthy"})
  ```
  
    ![app-healthy](output_images/image-16.png)

- **Git Fetch Failures:**
  ```promql
  increase(argocd_git_fetch_fail_total[5m])
  ```

---

## Concepts & Explanations

- **Metrics vs Logs vs Alerts:** Metrics are numeric time-series; logs are event records; alerts trigger on metrics thresholds.
- **ServiceMonitor:** CRD that tells Prometheus which Kubernetes services to scrape.
- **PromQL:** Prometheus Query Language to aggregate and filter metrics.
- **Grafana Dashboard:** Visual panels built using PromQL to display metrics over time.

*Enjoy comprehensive, production-ready monitoring for your ArgoCD GitOps workflow!*

Read More: [ArgoCD Metrics](https://argo-cd.readthedocs.io/en/latest/operator-manual/metrics/)

---

Happy Learning!
