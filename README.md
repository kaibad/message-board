# Message Board — DevOps Project 1

A 2-tier web application built with **Flask** and **MySQL**, containerized with Docker, deployed to Kubernetes using Helm on AWS EKS.

---

## Architecture

```
GitHub → GitHub Actions → DockerHub → ArgoCD → Kubernetes (Helm) → AWS EKS
```

- **Frontend + Backend:** Flask (Python)
- **Database:** MySQL
- **Containerization:** Docker
- **CI Pipeline:** GitHub Actions
- **Container Registry:** DockerHub
- **Orchestration:** Kubernetes
- **Package Manager:** Helm
- **GitOps/CD:** ArgoCD
- **Cloud:** AWS EKS

---

## Getting Started

### Prerequisites

- Python 3.12+
- MySQL
- pip

### Local Setup (Without Docker)

1. **Clone the repo**

   ```bash
   git clone https://github.com/kaibad/message-board.git
   cd message-board
   ```

2. **Create and activate virtual environment**

   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**

   ```bash
   pip install -r requirements.txt
   ```

4. **Set up MySQL**

   ```sql
   CREATE DATABASE flask_app;
   CREATE USER 'flask'@'localhost' IDENTIFIED BY 'flask123';
   GRANT ALL PRIVILEGES ON flask_app.* TO 'flask'@'localhost';
   FLUSH PRIVILEGES;
   ```

5. **Export environment variables**

   ```bash
   export MYSQL_HOST=localhost
   export MYSQL_USER=flask
   export MYSQL_PASSWORD=flask123
   export MYSQL_DB=flask_app
   ```

6. **Run the app**

   ```bash
   python app.py
   ```

7. **Visit** `http://localhost:5000`

---

## Docker

### What is Docker?

Docker is a platform that lets you **package your application and all its dependencies into a single unit called a container**. This container can run on any machine that has Docker installed — regardless of the underlying OS or environment.

> Think of it like a shipping container — you pack everything your app needs inside it, and it runs the same way everywhere.

Without Docker:

- "It works on my machine" problem
- Manual dependency installation on every server
- Environment mismatches between dev and prod

With Docker:

- One container = app + dependencies + config
- Runs identically on any machine
- Isolated from other processes on the host

---

### What is a Dockerfile?

A **Dockerfile** is a plain text file with step-by-step instructions that tells Docker **how to build your image**. It defines the base OS, installs dependencies, copies your code, and sets the startup command.

```
Dockerfile  →  (docker build)  →  Image
```

Example `Dockerfile` for this Flask app:

```dockerfile
FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
```

Each line in a Dockerfile is a **layer** — Docker caches layers, so if `requirements.txt` hasn't changed, it won't reinstall packages on the next build.

---

### What is a Docker Image?

A **Docker image** is the output of `docker build`. It is a **read-only snapshot** of your app — the filesystem, dependencies, and configuration all bundled together.

```bash
docker build -t message-board:latest .
```

- `-t` tags the image with a name
- Images are stored locally or pushed to a registry (DockerHub, ECR)
- Images are **immutable** — you never modify an image directly

---

### What is a Docker Container?

A **container** is a **running instance of an image**. When you run an image, Docker creates a container from it.

```bash
docker run -d -p 5000:5000 message-board:latest
```

Key concept:

```
One Image → Many Containers
```

You can spin up 10 containers from the same image simultaneously. Each container is isolated, has its own filesystem and network, but shares the host OS kernel.

|            | Image             | Container                           |
| ---------- | ----------------- | ----------------------------------- |
| State      | Read-only, static | Running, has state                  |
| Created by | `docker build`    | `docker run`                        |
| Analogy    | Blueprint / Class | House built from blueprint / Object |

---

### What is Docker Compose?

**Docker Compose** is a tool for defining and running **multi-container applications**. Instead of running `docker run` commands manually for each container, you define everything in a single `docker-compose.yml` file and start it all with one command.

This project has 2 services:

- `flask` — the web application
- `mysql` — the database

Without Compose you'd have to manually run, network, and configure them separately. With Compose:

```bash
docker compose up
```

That's it — both containers start, they're on the same network, and Flask can reach MySQL by hostname.

---

### Dockerization Steps

**Step 0 — Read the requirements and code for understanding.**

**Step 1 — Write the Dockerfile**

```dockerfile
# Build Stage
FROM python:3.12-alpine AS builder
WORKDIR /app

# Install build dependencies (Alpine way)
RUN apk add --no-cache \
    gcc \
    musl-dev \
    mariadb-dev \
    pkgconfig

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Stage 2
FROM python:3.12-alpine
WORKDIR /app

# Runtime dependencies only
RUN apk add --no-cache \
    mariadb-connector-c

COPY --from=builder /install /usr/local
COPY . .
EXPOSE 5000
CMD ["python","app.py"]
```

**Step 2 — Write docker-compose.yml**

```yaml
version: "3.8"

services:
  flask:
    build:
      context: .
    image: flask-message-app
    container_name: flask_message_app
    ports:
      - "5000:5000"
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: flask
      MYSQL_PASSWORD: flask123
      MYSQL_DB: flask_app
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    container_name: mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root12345
      MYSQL_USER: flask
      MYSQL_PASSWORD: flask123
      MYSQL_DATABASE: flask_app
    volumes:
      - ./mysql_data:/var/lib/mysql
    ports:
      - "33076:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    container_name: phpmyadmin
    restart: always
    ports:
      - "8080:80"
    environment:
      PMA_HOST: mysql
      PMA_USER: flask
      PMA_PASSWORD: flask123
    depends_on:
      - mysql

volumes:
  mysql_data:
```

**Step 3 — Build and run**

```bash
docker compose up --build
```

**Step 4 — Visit** `http://localhost:5000`

**Step 5 — Stop**

```bash
docker compose down
```

**Step 6 — Push image to DockerHub**

```bash
docker login
docker tag flask-message-app:latest kailashbadu/flask-message-app:latest
docker push kailashbadu/flask-message-app:v1.0.0
```

---

### Docker Flow Summary

```
Dockerfile
    ↓  docker build
  Image  ──────────────────────────→  DockerHub / ECR
    ↓  docker run
Container (1st instance)
Container (2nd instance)      ← same image, multiple containers
Container (3rd instance)
```

---

## Nginx

```nginx
upstream flask_app {
    server flask:5000;
}

server {
    listen 80;

    location / {
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Explanation

```nginx
# Defines a group of backend servers
upstream flask_app {
    server flask:5000;
}

server {
    # Nginx listens on port 80 (HTTP)
    listen 80;

    location / {
        # Forward incoming requests to the upstream group
        proxy_pass http://flask_app;

        # Pass original host (example: localhost or domain name)
        proxy_set_header Host $host;

        # Pass real client IP to backend (Flask app)
        proxy_set_header X-Real-IP $remote_addr;

        # Forward chain of IPs (useful if behind multiple proxies)
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Add in docker-compose.yml

```yaml
nginx:
  image: nginx:alpine
  container_name: nginx
  restart: always
  ports:
    - "80:80"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
  depends_on:
    - flask
```

### Remove the port exposure from flask service

```yaml
flask:
  build:
    context: .
  container_name: flask_message_app
  expose:
    - "5000" # ← change ports to expose
  environment: ...
```

---

## CI/CD with GitHub Actions

### What is CI/CD?

**CI/CD** stands for Continuous Integration and Continuous Delivery/Deployment. It is the practice of automating the steps between writing code and getting it running in production.

- **CI (Continuous Integration)** — automatically build and test code every time it is pushed
- **CD (Continuous Delivery/Deployment)** — automatically package and deploy that code after a successful build

Without CI/CD:

- Developer builds image manually on their machine
- Manually logs into DockerHub and pushes
- Easy to forget steps, push broken images, or use wrong tags

With CI/CD:

- Push a git tag → pipeline automatically builds, tags, and pushes the image
- Every release is consistent and traceable
- No manual steps, no human error

---

### What is GitHub Actions?

**GitHub Actions** is GitHub's built-in CI/CD platform. You define workflows as YAML files inside `.github/workflows/`. GitHub runs these workflows on their cloud servers (called **runners**) whenever a trigger event occurs — like a push, pull request, or a new tag.

```
.github/workflows/docker-build-push.yml  →  runs on GitHub's servers automatically
```

Key concepts:

| Concept            | What it is                                               |
| ------------------ | -------------------------------------------------------- |
| **Workflow**       | The entire automation file (`.yml`)                      |
| **Trigger (`on`)** | The event that starts the workflow (push, tag, PR)       |
| **Job**            | A group of steps that run on one runner                  |
| **Step**           | A single task inside a job (checkout, build, push)       |
| **Runner**         | The cloud VM that executes the job (`ubuntu-latest`)     |
| **Secret**         | Encrypted variables stored in GitHub (passwords, tokens) |

---

### Why Tag-Based Triggers?

This pipeline triggers on `v*` tags instead of every push to main. This means:

```
git tag v1.0.0
git push origin v1.0.0  →  pipeline runs
```

- Only intentional releases trigger a build
- Every DockerHub image is tied to a specific version tag
- Easy to roll back — just deploy an older tag

---

### Pipeline Workflow

```
Developer pushes tag (v1.0.0)
        ↓
GitHub Actions runner starts (ubuntu-latest)
        ↓
Step 1: Checkout code from repo
        ↓
Step 2: Login to DockerHub using secrets
        ↓
Step 3: docker build → creates image
        ↓
Step 4: docker tag → tags as v1.0.0 AND latest
        ↓
Step 5: docker push → uploads both tags to DockerHub
        ↓
DockerHub: kailashbadu/message-board:v1.0.0
           kailashbadu/message-board:latest
```

---

### Workflow File

`.github/workflows/docker-build-push.yml`

```yaml
name: Deploy-Message-Board

on:
  push:
    tags:
      - "v*"

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push Docker image
        run: |
          TAG=${{ github.ref_name }}
          docker build -t message-board .
          docker tag message-board ${{ secrets.DOCKERHUB_USERNAME }}/message-board:$TAG
          docker tag message-board ${{ secrets.DOCKERHUB_USERNAME }}/message-board:latest
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/message-board:$TAG
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/message-board:latest
```

---

### Setting Up Secrets

Go to: GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret               | Value                                 |
| -------------------- | ------------------------------------- |
| `DOCKERHUB_USERNAME` | your DockerHub username               |
| `DOCKERHUB_TOKEN`    | DockerHub access token (not password) |

To generate a DockerHub token: hub.docker.com → Account Settings → Security → **New Access Token**

---

### Triggering the Pipeline

```bash
git add .
git commit -m "feat: your changes"
git push
git tag v1.0.0
git push origin v1.0.0
```

Monitor the run at: `https://github.com/kaibad/message-board/actions`

---

## Kubernetes (K8s)

### What is Kubernetes?

**Kubernetes** is a container orchestration platform. Once you have containers running with Docker, Kubernetes manages them at scale — it handles:

- **Scheduling** — deciding which node runs which container
- **Self-healing** — restarting crashed containers automatically
- **Scaling** — adding more containers when traffic increases
- **Load balancing** — distributing traffic across containers
- **Rolling updates** — deploying new versions with zero downtime

> Docker runs one container. Kubernetes runs thousands of containers across many machines and keeps them healthy.

---

### Core Kubernetes Concepts

| Concept        | What it is                                             |
| -------------- | ------------------------------------------------------ |
| **Pod**        | Smallest unit in K8s — wraps one or more containers    |
| **Deployment** | Manages pods — defines how many replicas to run        |
| **Service**    | Exposes pods to network traffic (internal or external) |
| **ConfigMap**  | Stores non-sensitive config (env vars)                 |
| **Secret**     | Stores sensitive config (passwords, keys)              |
| **Namespace**  | Virtual cluster — logical separation within a cluster  |
| **Node**       | A physical or virtual machine in the cluster           |
| **Cluster**    | A group of nodes managed by Kubernetes                 |

---

### Local Cluster Setup (minikube)

minikube runs a single-node Kubernetes cluster on your local machine — perfect for learning and testing before moving to a cloud provider.

```bash
# Start the cluster
minikube start

# Verify node is ready
kubectl get nodes

# Check cluster info
kubectl cluster-info
```

---

### Namespace

A **namespace** is a virtual cluster inside your cluster. It logically isolates resources — so our app's pods, services, and secrets are separated from system resources in `kube-system`.

```bash
kubectl create namespace message-board
kubectl get namespaces
```

---

### Storage — PV and PVC

#### What is a PersistentVolume (PV)?

A PV is a **piece of storage provisioned in the cluster**. It exists independently of any pod — so even if the MySQL pod crashes or restarts, the data is still there.

#### What is a PersistentVolumeClaim (PVC)?

A PVC is a **request for storage by a pod**. The pod doesn't talk to the PV directly — it claims storage through a PVC.

```
Pod → PVC → PV → actual disk storage
```

**pv.yaml**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /data/mysql
```

**pvc.yaml**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: message-board
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f k8s/storage/pv.yaml
kubectl apply -f k8s/storage/pvc.yaml
kubectl get pv
kubectl get pvc -n message-board
```

When PVC shows `Bound` — storage is ready.

---

### Secret

Secrets store sensitive data like passwords. Values are base64 encoded and never hardcoded in deployment files.

**secret.yaml**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: message-board
type: Opaque
stringData:
  mysql-root-password: root12345
  mysql-password: flask123
```

```bash
kubectl apply -f k8s/app/secret.yaml
```

---

### MySQL Deployment + Service

**mysql.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: message-board
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-root-password
            - name: MYSQL_DATABASE
              value: flask_app
            - name: MYSQL_USER
              value: flask
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-password
          ports:
            - containerPort: 3306
          volumeMounts:
            - name: mysql-storage
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-storage
          persistentVolumeClaim:
            claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: message-board
spec:
  selector:
    app: mysql
  ports:
    - port: 3306
      targetPort: 3306
```

---

### Flask Deployment + Service

Flask deployment includes **liveness** and **readiness probes** to let Kubernetes know the health of the app.

#### What is a Liveness Probe?

Checks if the container is **still alive**. If it fails, Kubernetes **restarts** the container.

> "Is the app still running or is it stuck/crashed?"

#### What is a Readiness Probe?

Checks if the container is **ready to receive traffic**. If it fails, Kubernetes **removes it from the load balancer** but does NOT restart it.

> "Is the app ready to serve requests yet?"

```
Readiness fails → pod removed from Service endpoints (no traffic sent)
Liveness fails  → pod gets restarted
```

**flask.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask
  namespace: message-board
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flask
  template:
    metadata:
      labels:
        app: flask
    spec:
      containers:
        - name: flask
          image: kailashbadu/message-board:latest
          ports:
            - containerPort: 5000
          env:
            - name: MYSQL_HOST
              value: mysql-service
            - name: MYSQL_USER
              value: flask
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-password
            - name: MYSQL_DB
              value: flask_app
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
          livenessProbe:
            httpGet:
              path: /
              port: 5000
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /
              port: 5000
            initialDelaySeconds: 20
            periodSeconds: 5
            failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: flask-service
  namespace: message-board
spec:
  selector:
    app: flask
  ports:
    - port: 80
      targetPort: 5000
  type: NodePort
```

---

### Apply All Manifests

```bash
kubectl apply -f k8s/app/secret.yaml
kubectl apply -f k8s/app/mysql.yaml
kubectl apply -f k8s/app/flask.yaml

# verify everything is running
kubectl get all -n message-board
```

---

### HPA — Horizontal Pod Autoscaler

#### What is HPA?

HPA automatically **scales the number of pods up or down** based on CPU or memory usage.

```
Low traffic   → 2 pods
High traffic  → K8s adds more pods automatically (up to max)
Traffic drops → K8s removes extra pods
```

> Without HPA you manually change `replicas`. With HPA Kubernetes does it for you based on load.

#### Enable metrics-server on minikube

HPA needs metrics-server to read CPU/memory usage from pods:

```bash
minikube addons enable metrics-server
kubectl get pods -n kube-system | grep metrics
```

#### HPA Manifest

**hpa.yaml**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: flask-hpa
  namespace: message-board
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: flask
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

This means:

- Keep minimum **2 pods** always running
- Scale up to **5 pods** max
- If average CPU across pods exceeds **50%** → add more pods

```bash
kubectl apply -f k8s/hpa/hpa.yaml
kubectl get hpa -n message-board
```

---

### Ingress

#### What is Ingress?

Ingress is a Kubernetes resource that manages **external HTTP/HTTPS access** to services inside the cluster. It acts as a smart reverse proxy — one entry point that routes traffic to different services based on path or hostname.

```
Without Ingress:
  user → flask-service:31832 (NodePort — ugly port number)

With Ingress:
  user → ingress (port 80) → /  → flask-service
                            → /api → another-service
```

|              | NodePort/LoadBalancer | Ingress                     |
| ------------ | --------------------- | --------------------------- |
| Entry points | One per service       | One for all services        |
| URL routing  | Not supported         | Path and host based routing |
| SSL/TLS      | Manual per service    | Centralized at ingress      |
| Cost on AWS  | One ELB per service   | One ELB for everything      |

#### Enable Ingress on minikube

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

#### Ingress Manifest

**ingress.yaml**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: message-board-ingress
  namespace: message-board
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: message-board.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: flask-service
                port:
                  number: 80
```

```bash
kubectl apply -f k8s/ingress/ingress.yaml
kubectl get ingress -n message-board
```

#### Add host entry

```bash
# Add minikube IP to /etc/hosts
echo "$(minikube ip) message-board.local" | sudo tee -a /etc/hosts

# Verify
cat /etc/hosts | grep message-board
```

Visit `http://message-board.local` in your browser.

---

### Kubernetes Flow Summary

```
Docker Image (DockerHub)
        ↓
   Namespace created (message-board)
        ↓
   PV + PVC provisioned (MySQL storage)
        ↓
   Secret created (DB credentials)
        ↓
   MySQL Deployment → Pod → data stored on PVC
        ↓
   Flask Deployment → 2 Pods → liveness + readiness probes active
        ↓
   HPA watches CPU → scales Flask pods 2-5 automatically
        ↓
   Ingress → routes http://message-board.local → flask-service → pods
```

---

## Helm

### What is Helm?

**Helm** is the **package manager for Kubernetes**. Just like `apt` installs packages on Ubuntu or `pip` installs Python packages, Helm installs applications on Kubernetes.

Instead of managing multiple `kubectl apply -f` commands for each manifest, Helm bundles everything into a **Chart** — a package of all the Kubernetes manifests for an application.

> Helm = Kubernetes manifests + templating + versioning + one-command install

---

### Why Helm over plain kubectl?

| Plain kubectl                            | Helm                                    |
| ---------------------------------------- | --------------------------------------- |
| Apply each file manually                 | `helm install` does everything          |
| Hard to manage different envs (dev/prod) | Use `values.yaml` per environment       |
| No versioning or rollback                | `helm rollback` to any previous version |
| Duplicate YAML for similar apps          | Reusable templates                      |

---

### Helm Chart Structure

```
message-board/
├── Chart.yaml          # Chart metadata (name, version)
├── values.yaml         # Default config values
└── templates/
    ├── flask-deployment.yaml
    ├── flask-service.yaml
    ├── mysql-deployment.yaml
    └── mysql-service.yaml
```

**values.yaml**

```yaml
flask:
  image: kaibad/message-board
  tag: latest
  replicas: 2

mysql:
  image: mysql
  tag: "8.0"
  database: flask_app
  user: flask
```

**Install the chart:**

```bash
helm install message-board ./message-board
```

**Upgrade after changes:**

```bash
helm upgrade message-board ./message-board
```

**Rollback:**

```bash
helm rollback message-board 1
```

**Uninstall:**

```bash
helm uninstall message-board
```

---

---

## AWS EKS Deployment

### What is EKS?

**Amazon Elastic Kubernetes Service (EKS)** is AWS's managed Kubernetes service. Instead of setting up and managing your own Kubernetes control plane, AWS handles it for you. You just create a cluster and add worker nodes.

---

### Minikube vs EKS

| Aspect            | Minikube                      | EKS (AWS)                                  |
| ----------------- | ----------------------------- | ------------------------------------------ |
| Control Plane     | Your laptop/VM                | AWS managed, multi-AZ                      |
| Worker Nodes      | Same machine as control plane | Separate EC2 instances                     |
| Networking        | Local virtual network         | Real AWS VPC, subnets, security groups     |
| Load Balancer     | Not real (minikube tunnel)    | Real AWS ALB/NLB provisioned automatically |
| High Availability | None                          | Built-in across AZs                        |
| Access            | Local only                    | Accessible globally via IAM                |
| Use case          | Local dev/learning            | Staging, production                        |
| Cost              | Free (uses your CPU/RAM)      | Pay for EC2 nodes + $0.10/hr control plane |

---

### Phase 1 — Create IAM Roles

Before creating the cluster, two IAM roles are needed.

#### Role 1 — EKS Cluster Role

1. Go to **IAM → Roles → Create role**
2. Select **AWS Service** → Use case: **EKS** → Select **EKS - Cluster**
3. Click **Next → Next**
4. Role name: `eks-cluster-role`
5. Click **Create role**

#### Role 2 — Node Group Role

1. Go to **IAM → Roles → Create role**
2. Select **AWS Service** → Use case: **EC2** → **Next**
3. Attach these 3 policies:
   - `AmazonEKSWorkerNodePolicy` — allows node to register with EKS cluster
   - `AmazonEC2ContainerRegistryReadOnly` — allows node to pull images from ECR
   - `AmazonEKS_CNI_Policy` — allows VPC CNI plugin to manage network interfaces
4. Role name: `eks-nodegroup-role`
5. Click **Create role**

---

### Phase 2 — Create EKS Cluster

1. Search **EKS** in AWS Console → **Elastic Kubernetes Service**
2. Click **Create cluster**
3. **Configure cluster tab:**
   - Name: `message-board-cluster`
   - Kubernetes version: latest stable
   - Cluster IAM Role: `eks-cluster-role`
   - Click **Next**
4. **Networking tab:**
   - Select your **VPC** (default VPC is fine)
   - Select **at least 3 subnets** across different AZs (`us-east-1a`, `us-east-1b`, `us-east-1c`)
   - Select your **Security Group**
   - Cluster endpoint access: **Public and Private**
   - Click **Next**
5. **Observability tab:** Leave default → **Next**
6. **Add-ons tab:** Leave defaults → **Next**
7. **Configure add-on settings:** Select latest versions for all → **Next**
8. **Review → Create**

> ⏳ Cluster creation takes 10–15 minutes.

#### Why Minimum 3 Subnets?

1. **High Availability** — each subnet in a different AZ. If one AZ goes down, pods in other AZs keep running
2. **Load Balancer requirement** — AWS ALB/NLB require subnets in at least 2 AZs
3. **EKS Control Plane HA** — AWS runs control plane components across multiple AZs
4. **Pod scheduling spread** — Kubernetes can spread pod replicas across AZs
5. **AWS Best Practice** — a region has 3 AZs, use all 3

---

### Phase 3 — EC2 Management Instance

The EC2 management instance is a **client machine** — it runs `kubectl` and `helm` to send API requests to the EKS control plane. It is NOT a master node. AWS manages the actual control plane.

> If the management EC2 goes down, deployed pods keep running. You just lose the ability to run `kubectl` commands until restored.

#### Launch EC2

- AMI: **Ubuntu 22.04 LTS**
- Instance type: **t2.micro** (free tier)
- Security Group: allow SSH (port 22) from your IP

#### SSH into EC2

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

#### Install Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install
aws configure
# Enter: Access Key, Secret Key, region: us-east-1, output: json

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# eksctl
curl --silent --location \
  "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/
eksctl version

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Git
sudo apt update && sudo apt install git -y
```

---

### Phase 4 — Create Node Group

Worker nodes run your actual application pods.

1. Go to **EKS → message-board-cluster → Compute tab**
2. Click **Add Node Group**
3. **Configure:**
   - Name: `message-board-workers`
   - Node IAM Role: `eks-nodegroup-role`
   - Click **Next**
4. **Compute configuration:**
   - AMI type: `Amazon Linux 2 (AL2_x86_64)`
   - Instance type: `t3.medium`
   - Disk size: `20 GiB`
5. **Scaling configuration:**
   - Desired: `2`, Minimum: `1`, Maximum: `3`
6. Select your **3 subnets** → **Next** → **Create**

> ⏳ Takes 3–5 minutes.

#### Why Docker is Not Needed on Worker Nodes

EKS worker nodes use **containerd** directly (not Docker) since Kubernetes 1.24. When a pod is scheduled, the kubelet instructs containerd to pull the image and start the container — no Docker daemon involved. Public DockerHub images pull without authentication. For private ECR images, the node IAM role's `AmazonEC2ContainerRegistryReadOnly` policy handles auth automatically.

---

### Phase 5 — Connect kubectl to Cluster

```bash
aws eks update-kubeconfig --name=message-board-cluster --region=us-east-1
```

This command:

1. Calls the EKS API to get the cluster endpoint and certificate
2. Writes connection details to `~/.kube/config`
3. Sets the current context so all `kubectl` commands target this cluster

Verify:

```bash
kubectl get nodes
# NAME                            STATUS   ROLES    AGE
# ip-172-31-41-226.ec2.internal   Ready    <none>   7m
# ip-172-31-7-214.ec2.internal    Ready    <none>   7m
```

#### Troubleshooting — Unauthorized Error

If you get an `Unauthorized` error:

1. Go to **EKS → message-board-cluster → Access tab**
2. Click **Create access entry**
3. Get your IAM ARN:
   ```bash
   aws sts get-caller-identity --query Arn --output text
   ```
4. Add policies: `AmazonEKSAdminPolicy` + `AmazonEKSClusterPolicy`

#### Troubleshooting — i/o timeout

The EKS cluster security group only allows traffic from itself by default. Add an inbound rule:

1. Go to **EKS → message-board-cluster → Networking tab**
2. Click the **Cluster security group** (e.g., `sg-04cf0741e3ad55f34`)
3. **Edit inbound rules → Add rule:**
   - Type: **HTTPS**, Port: **443**, Source: **0.0.0.0/0**
4. Save

---

### Phase 6 — Deploy with Helm

Clone the repo on EC2 and deploy:

```bash
mkdir ~/kubernetes && cd ~/kubernetes
git clone https://github.com/kaibad/message-board.git
cd message-board

helm install message-board ~/kubernetes/message-board
kubectl get all
```

Expected output:

```
pod/message-board-flask-xxx   1/1   Running   2/2
pod/mysql-xxx                 1/1   Running   1/1
service/flask-service         NodePort
service/mysql-service         ClusterIP
deployment/message-board-flask  2/2
horizontalpodautoscaler       cpu: 2%/50%, memory: 34%/80%
```

---

### Phase 7 — ALB Ingress Controller

#### What is the AWS Load Balancer Controller?

The **AWS Load Balancer Controller** is a Kubernetes controller that watches for `Ingress` resources and automatically creates and configures AWS **Application Load Balancers (ALB)**. It replaces the nginx ingress controller used in minikube.

```
Without Ingress:
  Browser → NLB-1 → flask-service
  (one load balancer per service, expensive)

With ALB Ingress:
  Browser → ALB (1 load balancer)
             └── / → flask-service
  (one load balancer, one bill, one DNS name)
```

---

#### Step 1 — Add OIDC Provider to IAM

**What is OIDC?**
OpenID Connect (OIDC) is the mechanism that allows **Kubernetes Service Accounts to assume AWS IAM roles**. EKS acts as an identity provider — it issues tokens that AWS IAM trusts, so pods can call AWS APIs without hardcoded credentials. This is called **IRSA (IAM Roles for Service Accounts)**.

1. Go to **EKS → message-board-cluster → Overview tab**
2. Copy the **OpenID Connect provider URL**
3. Go to **IAM → Identity providers → Add provider**
   - Provider type: **OpenID Connect**
   - Provider URL: paste the OIDC URL
   - Audience: `sts.amazonaws.com`
4. Click **Add provider**

Get your OIDC ID:

```bash
aws eks describe-cluster --name message-board-cluster --region us-east-1 \
  --query "cluster.identity.oidc.issuer" --output text
# https://oidc.eks.us-east-1.amazonaws.com/id/ABC123...
# The part after /id/ is your OIDC ID
```

**What is AWS STS?**
AWS Security Token Service issues **temporary, short-lived credentials**. When a pod needs to call the AWS API, it presents its OIDC token to STS, which validates it and returns temporary credentials valid for ~1 hour. Far more secure than long-lived Access Keys stored in Secrets.

---

#### Step 2 — Create ALB Controller IAM Policy

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
```

1. Go to **IAM → Policies → Create policy**
2. Select **JSON** tab → paste contents of `iam_policy.json`
3. Policy name: `elb-policy`
4. Click **Create policy**

---

#### Step 3 — Create ALB IAM Role

1. **IAM → Roles → Create role → AWS Service → EC2 → Next**
2. Attach `elb-policy` → **Next**
3. Role name: `eks-alb-role` → **Create role**

Edit the trust relationship — click the role → **Trust relationships → Edit trust policy**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::290657649733:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/<YourOIDCId>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/<YourOIDCId>:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/<YourOIDCId>:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
```

| Field | Meaning                               | Example                                                          |
| ----- | ------------------------------------- | ---------------------------------------------------------------- |
| `aud` | Target service (who the token is for) | `sts.amazonaws.com`                                              |
| `sub` | Identity (which ServiceAccount)       | `system:serviceaccount:kube-system:aws-load-balancer-controller` |

Both must match — AWS verifies the correct receiver (`aud`) AND correct sender (`sub`).

---

#### Step 4 — Create Kubernetes Service Account

**What is a Service Account?**
A Service Account is an identity for **processes running inside pods**. By default pods use the `default` SA which has no AWS permissions. When annotated with an IAM role ARN, EKS injects an OIDC token into the pod and sets `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` env vars automatically — this is IRSA.

The ALB controller goes in `kube-system` because it is a cluster infrastructure component, separated from user workloads for security and operational clarity.

```bash
cat > sa.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::290657649733:role/eks-alb-role
EOF

kubectl apply -f sa.yaml
kubectl describe sa aws-load-balancer-controller -n kube-system
```

---

#### Step 5 — Install ALB Controller via Helm

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Get your VPC ID
aws ec2 describe-vpcs --region us-east-1 \
  --query "Vpcs[?IsDefault==\`true\`].VpcId" --output text

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=message-board-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=<YOUR_VPC_ID> \
  --version 1.14.0

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

---

#### Step 6 — Apply Ingress

```bash
cat > ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: message-board-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/subnets: <SubnetId-1>, <SubnetId-2>, <SubnetId-3>
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-port: "5000"
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: flask-service
                port:
                  number: 80
EOF

kubectl apply -f ingress.yaml
kubectl get ingress
```

Wait 2–3 minutes for ALB to provision. The `ADDRESS` column will populate with the ALB DNS name.

#### Ingress Annotation Explained

| Annotation                                   | Value             | Purpose                                          |
| -------------------------------------------- | ----------------- | ------------------------------------------------ |
| `alb.ingress.kubernetes.io/scheme`           | `internet-facing` | ALB is public. Use `internal` for VPC-only       |
| `alb.ingress.kubernetes.io/target-type`      | `ip`              | Routes directly to pod IPs (recommended for EKS) |
| `alb.ingress.kubernetes.io/subnets`          | Subnet IDs        | Public subnets where ALB is placed               |
| `alb.ingress.kubernetes.io/healthcheck-path` | `/`               | ALB health check path                            |
| `alb.ingress.kubernetes.io/healthcheck-port` | `5000`            | Health check port on the pod                     |

#### How the ALB is Created Automatically

When you `kubectl apply -f ingress.yaml`, the AWS Load Balancer Controller:

1. Detects the new Ingress object
2. Calls AWS API to create an ALB in the specified subnets
3. Creates target groups pointing to pod IPs
4. Creates listeners on port 80
5. Configures routing rules based on path
6. Writes the ALB DNS name back to `ingress.status`

---

### Full EKS Flow Summary

```
IAM Roles created (cluster + nodegroup)
        ↓
EKS Cluster created (AWS Console) — 3 subnets, public+private endpoint
        ↓
EC2 Management Instance — kubectl, helm, aws cli, eksctl installed
        ↓
Node Group created — 2x t3.medium EC2 worker nodes
        ↓
kubectl connected via aws eks update-kubeconfig
        ↓
Helm chart deployed — Flask + MySQL + HPA running
        ↓
OIDC provider added to IAM
        ↓
ALB Controller IAM Role + Service Account created (IRSA)
        ↓
AWS Load Balancer Controller installed via Helm
        ↓
Ingress applied → ALB provisioned automatically
        ↓
🌍 App live at ALB DNS: k8s-default-messageb-xxx.us-east-1.elb.amazonaws.com
```

---

### Troubleshooting

```bash
# ALB not being created — check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress events
kubectl describe ingress message-board-ingress

# Restart controller after changes
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

# Check pods
kubectl get pods -n kube-system | grep aws-load-balancer
```

Common causes of ALB not being created:

- IAM role ARN in Service Account annotation is wrong
- OIDC trust policy has wrong account ID or OIDC ID
- Subnets in Ingress annotation are private (need public for internet-facing)
- Subnets missing tag `kubernetes.io/role/elb: 1`

---

## GitOps with ArgoCD

### What is GitOps?

**GitOps** is a practice where your **Git repository is the single source of truth** for what should be running in your cluster. Instead of manually running `helm install` or `kubectl apply`, you push to Git and the cluster automatically updates itself.

```
Without GitOps:
  Developer → kubectl apply / helm install → Cluster
  (manual, error-prone, no audit trail)

With GitOps:
  Developer → git push → ArgoCD watches → Cluster auto-updates
  (automated, auditable, self-healing)
```

**Core GitOps principles:**

- Desired state lives in Git
- Changes happen through Pull Requests — full audit trail
- If someone manually changes the cluster, ArgoCD reverts it back to what Git says (self-healing)
- Rollback = `git revert`

---

### What is ArgoCD?

**ArgoCD** is a GitOps continuous delivery tool for Kubernetes. It runs inside your cluster and continuously watches your Git repo. When it detects a change (new image tag, updated values, new manifest), it automatically syncs the cluster to match.

```
Git repo (desired state)
        ↓  ArgoCD watches every ~3 minutes
Kubernetes cluster (actual state)
        ↓
If diff detected → ArgoCD syncs automatically
```

Key features:

- **Automated sync** — detects and applies changes automatically
- **Self-healing** — reverts manual kubectl changes that don't match Git
- **Prune** — removes resources that are deleted from Git
- **Visual UI** — shows full resource tree, sync status, pod health

---

### Full CI/CD + GitOps Flow

```
Developer pushes git tag (v1.0.3)
        ↓
GitHub Actions triggered
        ↓
Step 1: docker build → image built
        ↓
Step 2: docker push → kailashbadu/flask-message-app:v1.0.3 on DockerHub
        ↓
Step 3: sed updates tag in k8s/helm/message-board/values.yaml
        ↓
Step 4: git push → values.yaml committed to main branch
        ↓
ArgoCD detects values.yaml changed (polls every 3 min)
        ↓
ArgoCD runs helm upgrade on EKS cluster
        ↓
New pods with v1.0.3 image roll out (rolling update)
        ↓
🌍 Live at ALB DNS — zero manual steps
```

---

### Install ArgoCD on EKS

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Watch pods come up
kubectl get pods -n argocd -w
```

---

### Install ArgoCD CLI

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
argocd version
```

---

### Expose ArgoCD UI

By default ArgoCD server is `ClusterIP`. Change to `LoadBalancer` so it's accessible from browser:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc argocd-server -n argocd
```

Wait until `EXTERNAL-IP` is populated — it will be an AWS ALB DNS name.

Get the admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

Login at: `https://<EXTERNAL-IP>`

- **Username:** `admin`
- **Password:** output from above

> Browser will show a security warning — click **Advanced → Proceed** (self-signed cert).

---

### Login via CLI

```bash
argocd login <EXTERNAL-IP> \
  --username admin \
  --password <your-password> \
  --insecure
```

---

### Connect GitHub Repo

Since the repo is private, add credentials:

```bash
argocd repo add https://github.com/kaibad/message-board \
  --username kaibad \
  --password <github-personal-access-token> \
  --insecure
```

> Generate GitHub token: github.com → Settings → Developer settings → Personal access tokens → Generate new token → select `repo` scope

---

### Create ArgoCD Application

**argocd-app.yaml**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: message-board
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kaibad/message-board
    targetRevision: main
    path: k8s/helm/message-board
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

| Field                | Value                            | Meaning                               |
| -------------------- | -------------------------------- | ------------------------------------- |
| `repoURL`            | GitHub repo URL                  | Where ArgoCD watches for changes      |
| `targetRevision`     | `main`                           | Which branch to watch                 |
| `path`               | `k8s/helm/message-board`         | Path to Helm chart inside repo        |
| `destination.server` | `https://kubernetes.default.svc` | Deploy to same cluster ArgoCD runs in |
| `automated.prune`    | `true`                           | Delete resources removed from Git     |
| `automated.selfHeal` | `true`                           | Revert manual kubectl changes         |

```bash
kubectl apply -f argocd-app.yaml
kubectl get application -n argocd
```

Expected output:

```
NAME            SYNC STATUS   HEALTH STATUS
message-board   Synced        Healthy
```

---

### Updated GitHub Actions Workflow

The CI pipeline now has an extra step — after pushing the image, it updates the image tag in `values.yaml` and commits back to `main`. ArgoCD then detects this change and deploys.

`.github/workflows/docker-build-push.yml`

```yaml
name: Deploy Application

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          ref: main

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push Docker image
        run: |
          TAG=${{ github.ref_name }}
          docker build -t flask-message-app .
          docker tag flask-message-app ${{ secrets.DOCKERHUB_USERNAME }}/flask-message-app:$TAG
          docker tag flask-message-app ${{ secrets.DOCKERHUB_USERNAME }}/flask-message-app:latest
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/flask-message-app:$TAG
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/flask-message-app:latest

      - name: Update image tag in Helm values
        run: |
          TAG=${{ github.ref_name }}
          sed -i "s/tag: .*/tag: $TAG/" k8s/helm/message-board/values.yaml
          cat k8s/helm/message-board/values.yaml

      - name: Commit and push updated values.yaml
        run: |
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"
          git add k8s/helm/message-board/values.yaml
          git commit -m "ci: update image tag to ${{ github.ref_name }}"
          git push origin HEAD:main
```

**Why `permissions: contents: write`?**
By default GitHub Actions runner has read-only access to the repo. This permission grants write access so it can commit and push the updated `values.yaml` back to `main`.

**Why `ref: main` in checkout?**
When triggered by a tag push, the runner checks out the tag (detached HEAD state) by default. Specifying `ref: main` checks out the main branch instead — so the git push back to `main` works correctly.

---

### Triggering a Full GitOps Deployment

```bash
# Make a code change
vim app.py  # or any file

# Commit and push
git add .
git commit -m "feat: your changes"
git push

# Tag the release — this triggers the pipeline
git tag v1.0.3
git push origin v1.0.3
```

Then watch:

1. **GitHub Actions** tab — image build + values.yaml update
2. **ArgoCD UI** — detects change, syncs, rolls out new pods
3. **kubectl** — new pods with updated image

```bash
kubectl get pods -w
kubectl describe pod <flask-pod> | grep Image
```

---

### ArgoCD Commands

```bash
# Check app status
argocd app get message-board

# Manual sync (if needed)
argocd app sync message-board

# Check sync history
argocd app history message-board

# Rollback to previous version
argocd app rollback message-board 1

# List all apps
argocd app list

# Delete app
argocd app delete message-board
```

---

### ArgoCD Flow Summary

```
Git tag pushed
        ↓
GitHub Actions: build → push image → update values.yaml → git push
        ↓
ArgoCD detects values.yaml diff (polls every 3 min)
        ↓
ArgoCD: helm upgrade → rolling update on EKS
        ↓
Old pods terminate → new pods start with new image
        ↓
Readiness probe passes → pod added to load balancer
        ↓
ALB routes traffic to new pods
        ↓
Zero downtime deployment complete ✅
```

## Project Structure

```
message-board/
├── app.py                          # Flask application
├── requirements.txt                # Python dependencies
├── message.sql                     # Database schema
├── Dockerfile                      # Docker image instructions
├── docker-compose.yml              # Multi-container local setup
├── .env                            # Environment variables (not committed)
├── .gitignore
├── README.md
├── nginx/
│   └── nginx.conf                  # Nginx reverse proxy config
├── templates/
│   └── index.html                  # Frontend UI
├── .github/
│   └── workflows/
│       └── docker-build-push.yml   # GitHub Actions CI/CD pipeline
├── k8s/
│   ├── storage/
│   │   ├── pv.yaml
│   │   └── pvc.yaml
│   ├── app/
│   │   ├── secret.yaml
│   │   ├── mysql.yaml
│   │   └── flask.yaml
│   ├── hpa/
│   │   └── hpa.yaml
│   ├── ingress/
│   │   └── ingress.yaml
│   └── argocd/
│       └── argocd-app.yaml         # ArgoCD Application manifest
└── k8s/helm/
    └── message-board/
        ├── Chart.yaml
        ├── values.yaml             # Image tag updated by CI pipeline
        └── templates/
            ├── configmap.yaml
            ├── secret.yaml
            ├── pv.yaml
            ├── pvc.yaml
            ├── mysql-deployment.yaml
            ├── mysql-service.yaml
            ├── deployment.yaml
            ├── service.yaml
            ├── hpa.yaml
            ├── _helpers.tpl
            └── NOTES.txt
```

---

## Helm

### What is Helm?

**Helm** is the **package manager for Kubernetes**. Just like `apt` installs packages on Ubuntu or `pip` installs Python packages, Helm installs applications on Kubernetes.

Instead of managing multiple `kubectl apply -f` commands for each manifest, Helm bundles everything into a **Chart** — a package of all the Kubernetes manifests for an application.

> Helm = Kubernetes manifests + templating + versioning + one-command install

---

### Why Helm over plain kubectl?

| Plain kubectl                            | Helm                                    |
| ---------------------------------------- | --------------------------------------- |
| Apply each file manually                 | `helm install` does everything          |
| Hard to manage different envs (dev/prod) | Use `values.yaml` per environment       |
| No versioning or rollback                | `helm rollback` to any previous version |
| Duplicate YAML for similar apps          | Reusable templates                      |

---

### Helm Chart Structure

```
helm/message-board/
├── Chart.yaml              # Chart metadata (name, version, description)
├── values.yaml             # Default config values
└── templates/
    ├── configmap.yaml      # Non-sensitive env vars (MYSQL_HOST, MYSQL_DB)
    ├── secret.yaml         # Sensitive data (passwords)
    ├── pv.yaml             # PersistentVolume for MySQL
    ├── pvc.yaml            # PersistentVolumeClaim
    ├── mysql-deployment.yaml
    ├── mysql-service.yaml
    ├── deployment.yaml     # Flask deployment with probes + resources
    ├── service.yaml        # Flask NodePort service
    ├── hpa.yaml            # HPA (conditional on autoscaling.enabled)
    ├── _helpers.tpl        # Reusable template helpers
    └── NOTES.txt           # Post-install instructions
```

---

### Chart.yaml

```yaml
apiVersion: v2
name: message-board
description: A 2-tier Flask + MySQL message board app
type: application
version: 0.1.0
appVersion: "1.0.0"
```

---

### values.yaml

```yaml
replicaCount: 2

image:
  repository: kailashbadu/flask-message-app
  pullPolicy: Always
  tag: v1.0.1

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 50
  targetMemoryUtilizationPercentage: 80

livenessProbe:
  httpGet:
    path: /
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /
    port: 5000
  initialDelaySeconds: 20
  periodSeconds: 5
  failureThreshold: 3

service:
  type: NodePort
  port: 80
  targetPort: 5000

ingress:
  enabled: false

namespace: message-board

mysql:
  image: mysql
  tag: "8.0"
  database: flask_app
  user: flask
  rootPassword: root12345
  password: flask123
  storage: 1Gi
```

---

### Helm Commands

**Scaffold a new chart:**

```bash
helm create message-board
```

**Validate templates without deploying:**

```bash
helm template .
```

**Install:**

```bash
helm install message-board . --namespace default
```

**Check release:**

```bash
helm list
```

**Upgrade after changes:**

```bash
helm upgrade message-board .
```

**Rollback to previous version:**

```bash
helm rollback message-board 1
```

**Uninstall:**

```bash
helm uninstall message-board
```

---

### Helm Flow Summary

```
values.yaml  +  templates/
        ↓  helm template (renders YAML)
        ↓  helm install
Kubernetes receives all manifests in one shot
        ↓
Secret → ConfigMap → PV → PVC → MySQL → Flask → HPA
```

---

### Exec into MySQL pod

```bash
# Get pod name
kubectl get pods

# Exec into pod
kubectl exec -it <mysql-pod-name> -- bash

# Connect to MySQL (use -h 127.0.0.1 to force TCP not socket)
mysql -u root -proot12345 -h 127.0.0.1

# Inside MySQL
SHOW DATABASES;
USE flask_app;
SHOW TABLES;
SELECT * FROM messages;
```

---

## Standalone Ingress (Global)

Ingress is kept outside the Helm chart as a global cluster-level resource — not tied to a specific release. This way it can be managed independently and reused across deployments.

### ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: message-board-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: message-board.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: flask-service
                port:
                  number: 80
```

### Apply

```bash
kubectl apply -f k8s/ingress.yml
kubectl get ingress
```

### Add host entry

```bash
# Get minikube IP
minikube ip

# Add to /etc/hosts
echo "$(minikube ip) message-board.local" | sudo tee -a /etc/hosts

# Verify
cat /etc/hosts | grep message-board
```

Visit `http://message-board.local` in your browser.

---

## Tech Stack

| Layer            | Technology                         |
| ---------------- | ---------------------------------- |
| Backend          | Flask (Python)                     |
| Database         | MySQL                              |
| Reverse Proxy    | Nginx                              |
| Containerization | Docker                             |
| Orchestration    | Kubernetes                         |
| Autoscaling      | HPA                                |
| Ingress (local)  | Nginx Ingress                      |
| Ingress (AWS)    | AWS ALB (Load Balancer Controller) |
| Package Manager  | Helm                               |
| CI Pipeline      | GitHub Actions                     |
| CD / GitOps      | ArgoCD                             |
| Cloud            | AWS EKS                            |

---

## Author

**Kailash** — [@kaibad](https://github.com/kaibad)
