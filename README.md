# WeatherApp - Full CI/CD Pipeline

A Flask-based weather forecast application with a complete CI/CD pipeline, Kubernetes deployment on EKS, and AWS infrastructure managed through Terraform.

## Architecture Overview

This project implements a weather forecast web application with end-to-end DevOps infrastructure:

- **Application**: Python/Flask web app that fetches 7-day weather forecasts from the Visual Crossing API, with local JSON caching and Prometheus metrics.
- **Containerization**: Dockerized with Gunicorn, pushed to Docker Hub with git commit SHA tags for traceability.
- **CI/CD**: Jenkins pipeline that lints, tests, builds, and deploys to EKS using `kubectl`. Images are tagged with git commit SHAs for full traceability.
- **Infrastructure**: AWS resources (VPC, EC2, EKS, ALB, Route53, ACM) fully managed with modular Terraform.
- **Orchestration**: Kubernetes deployment on EKS with rolling updates, routed through an ALB via NodePort.

### Tech Stack

**App:** Python 3.9, Flask, Gunicorn, Jinja2, Bootstrap 5, Prometheus client.

**CI/CD:** Jenkins (controller + agent), GitLab CE, Docker Hub, Slack notifications.

**IaC:** Terraform (modular, S3 remote state, DynamoDB locking).

**AWS:** VPC, EC2, EKS, ALB, Route53, ACM, NAT Gateway, IAM.

**Containers:** Docker, Kubernetes (EKS).

### Pipeline Flow

```
 Developer        GitLab CE         Jenkins             Docker Hub         EKS Cluster
 ────────         ─────────         ───────             ──────────         ───────────
    │                 │                 │                     │               │
    │  git push       │                 │                     │               │
    ├────────────────►│  webhook        │                     │               │
    │                 ├────────────────►│                     │               │
    │                 │                 │  Install Deps       │               │
    │                 │                 │  Pylint             │               │
    │                 │                 │  Unit Tests         │               │
    │                 │                 │  Docker Build       │               │
    │                 │                 │  Docker Test        │               │
    │                 │                 │                     │               │
    │                 │                 │  docker push        │               │
    │                 │                 │  (:commit-sha +     │               │
    │                 │                 │   :latest)          │               │
    │                 │                 ├────────────────────►│               │
    │                 │                 │                     │               │
    │                 │                 │  kubectl apply + set image          │
    │                 │                 ├────────────────────────────────────►│
    │                 │                 │                     │               │
    │                 │                 │  Slack notification │               │
    │  ◄──────────────┼─────────────────┤                     │               │
    │                 │                 │                     │               │
```

### Infrastructure Diagram

```
                        ┌─────────────────────────────────────────────────────────┐
                        │                      AWS VPC (10.0.0.0/16)              │
                        │                                                         │
    Internet            │   Public Subnets              Private Subnets           │
    ───────             │   ──────────────              ───────────────           │
        │               │                                                         │
        ▼               │   ┌───────────┐               ┌──────────────────┐     │
   Route53 (DNS)        │   │    ALB    │──────────────►│  EKS Cluster     │     │
   *.source-code.click  │   │           │  NodePort     │  (WeatherApp x2  │     │
        │               │   │  HTTP→    │  30080        │   port 8080)     │     │
        ▼               │   │  HTTPS    │               └──────────────────┘     │
   ┌─────────┐          │   │  redirect │                                        │
   │   ACM   │          │   │           │               ┌──────────────────┐     │
   │  (TLS)  │─────────►│   │  Host-    │──────────────►│  GitLab CE       │     │
   └─────────┘          │   │  based    │  port 80      └──────────────────┘     │
                        │   │  routing  │               ┌──────────────────┐     │
                        │   │           │──────────────►│  Jenkins         │     │
                        │   │           │  port 8080    │  Controller      │     │
                        │   └───────────┘               └──────────────────┘     │
                        │                               ┌──────────────────┐     │
                        │   ┌───────────┐               │  Jenkins Agent   │     │
                        │   │    NAT    │               │  (builds +       │     │
                        │   │  Gateway  │◄──────────────│   deploys to EKS)│     │
                        │   │  (egress) │               └──────────────────┘     │
                        │   └───────────┘                                        │
                        │                               Internal DNS:            │
                        │   ┌───────────┐               jenkins-controller       │
                        │   │    IGW    │                 .internal:8080          │
                        │   └───────────┘                                        │
                        └─────────────────────────────────────────────────────────┘
```

### Design Decisions

**Kubernetes on EKS** — The weather app runs as a 2-replica Deployment with a NodePort Service on the EKS cluster. The ALB routes `app.source-code.click` to the NodePort (30080) on the EKS nodes. This provides self-healing, rolling updates, and horizontal scaling.

**Git commit SHA image tags** — Docker images are tagged with the short git commit hash (e.g. `yevgenio/weatherapp:2cca0b4`). This ties every deployment to a specific commit for traceability and easy rollbacks. A `latest` tag is also pushed for convenience.

**Jenkins agent provisioned via userdata** — The agent EC2 instance is fully bootstrapped through a Terraform-managed userdata script (`jenkins-agent.sh`) that installs Java, Python, pip, Docker, kubectl, and the AWS CLI, then registers the agent with the Jenkins controller via systemd. This means the agent is ready to build and deploy immediately after `terraform apply`.

**Self-hosted GitLab + Jenkins** — All CI/CD tooling runs on infrastructure we control (EC2 instances in private subnets), rather than relying on SaaS platforms.

**Single NAT Gateway (dev)** — The dev environment uses a single NAT gateway to reduce costs. For production, switch to one NAT per AZ by setting `single_nat_gateway = false`.

**Private DNS** — A Route53 private hosted zone (`*.internal`) allows instances to communicate by name (e.g. `jenkins-controller.internal:8080`) instead of hardcoded IPs.

## Project Structure

```
application/                        # Flask weather application
├── main.py                         # Flask routes, input sanitization, Prometheus metrics
├── provider.py                     # Weather API integration with caching
├── secret.py                       # API key
├── tests.py                        # Unit tests (unittest)
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Python 3.9 + Gunicorn (4 workers, port 8080)
├── Jenkinsfile                     # 7-stage CI/CD pipeline
├── weatherapp.yaml                 # Kubernetes Deployment + NodePort Service
├── templates/
│   ├── page.html                   # Main page template (Bootstrap 5)
│   └── day.html                    # Forecast day card macro
└── static/
    ├── style.css                   # CSS animations
    └── icons/                      # Weather condition icons (22 PNGs)

docker/                             # Standalone Docker Compose deployment
├── Dockerfile                      # Python 3.9 + Gunicorn
├── docker-compose.yml              # 2x Flask instances + Nginx load balancer
└── default.conf                    # Nginx upstream config

jenkins/                            # CI/CD server configuration
├── controller/
│   └── docker-compose.yml          # Jenkins LTS server (ports 8080, 50000)
└── agent/
    ├── docker-compose.yml          # Jenkins inbound agent config
    └── Dockerfile                  # Custom agent image with Docker CLI

gitlab/                             # Source code management
└── docker-compose.yml              # GitLab CE self-hosted instance

kubernetes/                         # K8s manifests (reference copy)
└── weatherapp.yaml                 # 2-replica Deployment + NodePort Service (port 30080)

terraform/                          # Infrastructure as Code
├── bootstrap/
│   └── main.tf                     # Remote state backend (S3 + DynamoDB)
└── project/
    ├── environments/
    │   └── dev/
    │       ├── main.tf             # Root module - composes all modules
    │       ├── variables.tf        # Input variable definitions
    │       ├── outputs.tf          # Output definitions
    │       ├── backend.tf          # S3 remote state config
    │       └── terraform.tfvars    # Dev environment values
    └── modules/
        ├── vpc/                    # VPC, subnets, IGW, NAT, route tables
        ├── eks/                    # EKS cluster + managed node group
        ├── compute/                # EC2 instances + security groups + IAM + userdata scripts
        │   └── scripts/
        │       └── jenkins-agent.sh  # Agent bootstrap (Java, Python, Docker, kubectl, AWS CLI)
        ├── dns/                    # Route53 zones + ACM certificate + internal DNS
        └── alb/                    # Application Load Balancer + host-based routing
```

## Getting Started

### Prerequisites

- **Python 3.9+**
- **Docker & Docker Compose**
- **Terraform >= 1.0**
- **kubectl**
- **AWS CLI** — configured via `aws configure` or `aws configure sso`
- **SSH key pair** — generate one for Terraform EC2 access:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/terraform-key
  ```
- **A domain** registered and managed via Route53 (default: `source-code.click`)
- **A [Visual Crossing Weather API](https://www.visualcrossing.com/) key** (free tier available)

### 1. Run the Application Locally

```bash
cd application
pip install -r requirements.txt
```

Add your API key to `secret.py`:

```python
API_KEY = 'YOUR_VISUAL_CROSSING_API_KEY'
```

Run the app:

```bash
python main.py
```

The app will be available at `http://localhost:8080`.

### 2. Run Tests

```bash
cd application
python3 -m unittest tests.py
pylint *.py --fail-under=5.0
```

### 3. Run with Docker Compose (Local Dev)

Build and run the containerized stack (2 Flask instances + Nginx load balancer):

```bash
cd docker
docker build -t yevgenio/weatherapp:latest -f Dockerfile ../application/
docker-compose up -d
```

The app will be available at `http://localhost:80` with load balancing across two instances.

## Infrastructure Setup (Terraform)

The infrastructure is organized into reusable modules and deployed to AWS `us-east-1`.

### Step 1: Bootstrap Remote State

Creates the S3 bucket and DynamoDB table for Terraform state management:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### Step 2: Deploy Infrastructure

```bash
cd terraform/project/environments/dev
terraform init
terraform plan
terraform apply
```

This provisions the full environment:

| Module      | Resources                                                                 |
|-------------|---------------------------------------------------------------------------|
| **VPC**     | VPC (10.0.0.0/16), 2 public + 2 private subnets, IGW, NAT Gateway       |
| **EKS**     | Kubernetes 1.32 cluster, managed node group (2-4 t3.medium nodes)        |
| **Compute** | 3 EC2 instances: GitLab, Jenkins controller, Jenkins agent (with userdata) |
| **DNS**     | Route53 hosted zone, wildcard ACM certificate, public + private DNS records |
| **ALB**     | Application Load Balancer with host-based routing, HTTP-to-HTTPS redirect |

### Network Architecture

- All EC2 and EKS instances run in **private subnets** with NAT egress.
- The ALB sits in **public subnets** and routes traffic by subdomain:
  - `app.source-code.click` / `eks.source-code.click` → EKS WeatherApp (NodePort 30080)
  - `gitlab.source-code.click` → GitLab (port 80)
  - `jenkins.source-code.click` → Jenkins controller (port 8080)
- Jenkins agent communicates with the controller via **private DNS** (`jenkins-controller.internal:8080`).
- Jenkins agent has **IAM-based EKS access** — no credentials stored, authentication is through the instance's IAM role.

### Environment Configuration

Edit `terraform/project/environments/dev/terraform.tfvars` to customize:

```hcl
environment              = "dev"
domain_name              = "source-code.click"
vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs     = ["10.0.11.0/24", "10.0.12.0/24"]
single_nat_gateway       = true
cluster_name             = "dev-eks"
cluster_version          = "1.32"
node_instance_types      = ["t3.medium"]
node_min_size            = 2
node_max_size            = 4
node_desired_size        = 2
```

## CI/CD Pipeline (Jenkins)

### Pipeline Stages

The `application/Jenkinsfile` defines a 7-stage pipeline:

| Stage | Description |
|-------|-------------|
| **Install Dependencies** | `pip3 install -r requirements.txt` |
| **Pylint** | Code quality gate (minimum score: 5.0) |
| **Unittest** | Runs `python3 -m unittest tests.py` |
| **Build Docker Image** | Builds `yevgenio/weatherapp:<git-commit-sha>` |
| **Test Docker Image** | Spins up container, health-checks port 8080 |
| **Push to Docker Hub** | Pushes both `:<commit-sha>` and `:latest` tags |
| **Deploy to EKS** | `kubectl apply` + `kubectl set image` + `kubectl rollout status` |

Post-build notifications are sent to a `#weather-jenkins` Slack channel on success or failure.

### Jenkins Setup

1. **Jenkins controller** runs on an EC2 instance, accessible at `jenkins.source-code.click`.

2. **Jenkins agent** is automatically provisioned via Terraform userdata (`compute/scripts/jenkins-agent.sh`). On first boot, the agent installs all required tools (Java, Python, pip, Docker, kubectl, AWS CLI), configures kubeconfig for EKS, and registers itself with the controller as a systemd service.

3. **Required Jenkins credentials:**
   - `dockerhub-creds` (Username with password) — Docker Hub account for image push

4. **Required Jenkins plugins:**
   - Docker Pipeline
   - Slack Notification

## GitLab Setup

GitLab CE runs on a dedicated EC2 instance, accessible at `gitlab.source-code.click`. SSH is available on port **2424** (to avoid conflict with the host SSH on port 22).

## Kubernetes Deployment

The weather app is deployed to EKS automatically by the Jenkins pipeline. The manifest (`application/weatherapp.yaml`) defines:

- **Deployment**: 2 replicas of the weather app container (port 8080)
- **Service**: NodePort type, mapping port 80 → 8080, exposed on nodePort 30080

The ALB routes external traffic from `app.source-code.click` to the NodePort on the EKS nodes.

To manually check the deployment:

```bash
kubectl get pods -l app=weatherapp
kubectl get svc weatherapp
```

## Monitoring

The application exposes Prometheus metrics at the `/metrics` endpoint:

- `home_visit_total` — Counter for homepage visits
- `result_returned_total` — Counter for forecast results served
- `api_call_duration_seconds` — Summary of weather API call latency
