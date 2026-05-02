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

## Running with Docker

> Coming soon

---

## Deploying to Kubernetes with Helm

> Coming soon

---

## AWS EKS Deployment

> Coming soon

---

## Project Structure

```
message-board/
├── app.py              # Flask application
├── requirements.txt    # Python dependencies
├── message.sql         # Database schema
├── .env                # Environment variables (not committed)
├── .gitignore
├── README.md
└── templates/
    └── index.html      # Frontend UI
```

---

## Tech Stack

| Layer            | Technology     |
| ---------------- | -------------- |
| Backend          | Flask (Python) |
| Database         | MySQL          |
| Containerization | Docker         |
| Orchestration    | Kubernetes     |
| Helm Charts      | Helm           |
| Cloud            | AWS EKS        |
