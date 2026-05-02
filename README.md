# Message Board — DevOps Project 1

A 2-tier web application built with **Flask** and **MySQL**, containerized with Docker, deployed to Kubernetes using Helm on AWS EKS.

---

## Architecture

```
GitHub → Docker → DockerHub → Kubernetes (Helm) → AWS EKS
```

- **Frontend + Backend:** Flask (Python)
- **Database:** MySQL
- **Containerization:** Docker
- **Orchestration:** Kubernetes
- **Package Manager:** Helm
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

## AWS EKS Deployment

### What is EKS?

**Amazon Elastic Kubernetes Service (EKS)** is AWS's managed Kubernetes service. Instead of setting up and managing your own Kubernetes control plane, AWS handles it for you. You just create a cluster and add worker nodes.

---

### EKS Setup Steps

**Step 1 — Install tools**

```bash
# AWS CLI
sudo apt install awscli -y
aws configure

# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# kubectl
sudo snap install kubectl --classic

# helm
sudo snap install helm --classic
```

**Step 2 — Create EKS cluster**

```bash
eksctl create cluster \
  --name message-board \
  --region ap-south-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2
```

**Step 3 — Connect kubectl to EKS**

```bash
aws eks update-kubeconfig --region ap-south-1 --name message-board
kubectl get nodes  # verify connection
```

**Step 4 — Push image to DockerHub**

```bash
docker build -t kaibad/message-board:latest .
docker push kaibad/message-board:latest
```

**Step 5 — Deploy with Helm**

```bash
helm install message-board ./helm/message-board
```

**Step 6 — Get the external IP**

```bash
kubectl get svc flask-service
```

Visit the `EXTERNAL-IP` in your browser.

---

### Full Project Flow

```
Code pushed to GitHub
        ↓
Docker builds image from Dockerfile
        ↓
Image pushed to DockerHub
        ↓
Helm installs chart on AWS EKS cluster
        ↓
K8s creates Pods (Flask + MySQL containers)
        ↓
LoadBalancer Service exposes Flask to internet
        ↓
Users access the Message Board
```

---

## Project Structure

```
message-board/
├── app.py                  # Flask application
├── requirements.txt        # Python dependencies
├── message.sql             # Database schema
├── Dockerfile              # Docker image instructions
├── docker-compose.yml      # Multi-container local setup
├── .env                    # Environment variables (not committed)
├── .gitignore
├── README.md
├── nginx/
│   └── nginx.conf          # Nginx reverse proxy config
├── templates/
│   └── index.html          # Frontend UI
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
│   └── ingress/
│       └── ingress.yaml
└── helm/
    └── message-board/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
```

---

## Tech Stack

| Layer            | Technology     |
| ---------------- | -------------- |
| Backend          | Flask (Python) |
| Database         | MySQL          |
| Reverse Proxy    | Nginx          |
| Containerization | Docker         |
| Orchestration    | Kubernetes     |
| Autoscaling      | HPA            |
| Ingress          | Nginx Ingress  |
| Helm Charts      | Helm           |
| Cloud            | AWS EKS        |

---

## Author

**Kailash** — [@kaibad](https://github.com/kaibad)
