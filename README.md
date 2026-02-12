# WeatherApp - Full CI/CD Pipeline

A Flask-based weather forecast application with a complete CI/CD pipeline, containerized deployment, and AWS infrastructure managed through Terraform.

## Architecture Overview

This project implements a weather forecast web application with end-to-end DevOps infrastructure:

- **Application**: Python/Flask web app that fetches 7-day weather forecasts from the Visual Crossing API, with local JSON caching and Prometheus metrics.
- **Containerization**: Dockerized with Nginx reverse proxy load-balancing across two Flask/Gunicorn instances.
- **CI/CD**: Jenkins pipeline that lints, tests, builds, and deploys the Docker image to an EC2 instance via Docker Compose.
- **Infrastructure**: AWS resources (VPC, EC2, EKS, ALB, Route53, ACM) fully managed with Terraform modules.
- **Orchestration**: Kubernetes deployment manifests for running on EKS.

### Tech Stack

**App:** Python 3.9, Flask, Gunicorn, Jinja2, Bootstrap 5, Prometheus client.

**CI/CD:** Jenkins (controller + agent), GitLab CE, Docker Hub, Slack notifications.

**IaC:** Terraform (modular, S3 remote state, DynamoDB locking).

**AWS:** VPC, EC2, EKS, ALB, Route53, ACM, NAT Gateway, IAM.

**Containers:** Docker, Docker Compose, Nginx, Kubernetes.

### Pipeline Flow

```
 Developer        GitLab CE         Jenkins             Docker Hub         AWS
 ────────         ─────────         ───────             ──────────         ───
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
    │                 │                 ├────────────────────►│               │
    │                 │                 │                     │               │
    │                 │                 │  SSH + docker-compose up            │
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
   *.source-code.click  │   │           │               │  (WeatherApp     │     │
        │               │   │  HTTP→    │               │   NodePort 30080)│     │
        ▼               │   │  HTTPS    │               └──────────────────┘     │
   ┌─────────┐          │   │  redirect │               ┌──────────────────┐     │
   │   ACM   │          │   │           │──────────────►│  GitLab CE       │     │
   │  (TLS)  │─────────►│   │  Host-    │               └──────────────────┘     │
   └─────────┘          │   │  based    │               ┌──────────────────┐     │
                        │   │  routing  │──────────────►│  Jenkins         │     │
                        │   │           │               │  (controller +   │     │
                        │   │           │               │   agent)         │     │
                        │   └───────────┘               └──────────────────┘     │
                        │                                                         │
                        │   ┌───────────┐               ┌──────────────┐         │
                        │   │    IGW    │               │  NAT Gateway │         │
                        │   └───────────┘               │  (egress)    │         │
                        │                               └──────────────┘         │
                        └─────────────────────────────────────────────────────────┘
```

### Design Decisions

**Two deployment strategies** — The project includes two deployment methods using the same Docker image (`yevgenio/weatherapp`):

1. **Kubernetes on EKS (primary)** — The production deployment. A 2-replica Deployment with a NodePort Service runs on the EKS cluster, routed through the ALB at `app.source-code.click`. This provides self-healing, rolling updates, and horizontal scaling.

2. **Docker Compose (standalone)** — Included in the `docker/` folder for local development or lightweight single-server deployments. Two Flask/Gunicorn instances sit behind an Nginx reverse proxy. The Jenkins pipeline can also deploy this way to an EC2 instance via SSH.

**Self-hosted GitLab + Jenkins** — All CI/CD tooling runs on infrastructure we control (EC2 instances in private subnets), rather than relying on SaaS platforms. This demonstrates end-to-end infrastructure ownership.

**Single NAT Gateway (dev)** — The dev environment uses a single NAT gateway to reduce costs. For production, this can be switched to one NAT per AZ by setting `single_nat_gateway = false` in `terraform.tfvars`.

## Project Structure

```
application/                        # Flask weather application
├── main.py                         # Flask routes, input sanitization, Prometheus metrics
├── provider.py                     # Weather API integration with caching
├── secret.py                       # API key (placeholder - replace with your own)
├── tests.py                        # Unit tests (unittest)
├── requirements.txt                # Python dependencies
├── templates/
│   ├── page.html                   # Main page template (Bootstrap 5)
│   └── day.html                    # Forecast day card macro
└── static/
    ├── style.css                   # CSS animations
    └── icons/                      # Weather condition icons (22 PNGs)

docker/                             # Containerization
├── Dockerfile                      # Python 3.9 + Gunicorn (4 workers, port 8080)
├── docker-compose.yml              # 2x Flask instances + Nginx load balancer
└── default.conf                    # Nginx upstream config for load balancing

jenkins/                            # CI/CD pipeline
├── Jenkinsfile                     # 7-stage pipeline (lint → test → build → deploy)
├── controller/
│   └── docker-compose.yml          # Jenkins LTS server (ports 8080, 50000)
└── agent/
    ├── docker-compose.yml          # Jenkins inbound agent config
    ├── Dockerfile                  # Custom agent image with Docker CLI
    └── agent.sh                    # Systemd service for agent registration

gitlab/                             # Source code management
└── docker-compose.yml              # GitLab CE self-hosted instance

kubernetes/                         # K8s deployment manifests
└── weatherapp.yaml                 # 2-replica Deployment + NodePort Service (port 30080)

terraform/                          # Infrastructure as Code
├── terraform.sh                    # Helper script (init, plan, apply, destroy)
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
        ├── compute/                # EC2 instances + security groups + IAM
        ├── dns/                    # Route53 zones + ACM certificate
        └── alb/                    # Application Load Balancer + target groups
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

### Placeholders to Replace

Several config files contain `<PLACEHOLDER>` values that must be set before use:

| File | Placeholder | Description |
|------|-------------|-------------|
| `application/secret.py` | `YOUR_API_KEY_HERE` | Visual Crossing Weather API key |
| `jenkins/Jenkinsfile` | `<APP_EC2_IP>` | IP of the EC2 instance running the weather app |
| `jenkins/agent/docker-compose.yml` | `<JENKINS_CONTROLLER_IP>`, `<JENKINS_AGENT_SECRET>` | Jenkins controller address and agent auth token |
| `jenkins/agent/agent.sh` | `<JENKINS_CONTROLLER_IP>`, `<JENKINS_AGENT_SECRET>` | Same as above, for the systemd service variant |
| `gitlab/docker-compose.yml` | `<GITLAB_SERVER_IP>` | IP or domain of the GitLab host |

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

### 3. Run with Docker Compose

Build and run the containerized stack (2 Flask instances + Nginx load balancer):

> [!NOTE]
> The Dockerfile uses `COPY . /code`, so it expects the application source files as the build context. When building from the `docker/` directory, point the context to `../application/`.

```bash
cd docker
docker build -t yevgenio/weatherapp:latest -f Dockerfile ../application/
docker-compose up -d
```

The app will be available at `http://localhost:80` with load balancing across two instances.

To stop:

```bash
docker-compose down
```

## Infrastructure Setup (Terraform)

The infrastructure is organized into reusable modules and deployed to AWS `us-east-1`.

### Step 1: Bootstrap Remote State

This creates the S3 bucket and DynamoDB table used for Terraform state management:

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

| Module    | Resources                                                                 |
|-----------|---------------------------------------------------------------------------|
| **VPC**   | VPC (10.0.0.0/16), 2 public + 2 private subnets, IGW, NAT Gateway       |
| **EKS**   | Kubernetes 1.31 cluster, managed node group (2-4 t3.medium nodes)        |
| **Compute** | 3 EC2 instances: gitlab, jenkins-controller, jenkins-agent |
| **DNS**   | Route53 hosted zone, wildcard ACM certificate, public + private DNS records |
| **ALB**   | Application Load Balancer with host-based routing, HTTP-to-HTTPS redirect   |

### Network Architecture

- All EC2 and EKS instances run in **private subnets** with NAT egress.
- The ALB sits in **public subnets** and routes traffic by subdomain:
  - `app.source-code.click` / `eks.source-code.click` -> EKS WeatherApp (NodePort 30080)
  - `gitlab.source-code.click` -> GitLab (port 80)
  - `jenkins.source-code.click` -> Jenkins controller (port 8080)

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
cluster_version          = "1.31"
node_instance_types      = ["t3.medium"]
node_min_size            = 2
node_max_size            = 4
node_desired_size        = 2
```

To tear down:

```bash
terraform destroy
```

## CI/CD Pipeline (Jenkins)

### Setting Up Jenkins

1. **Deploy Jenkins controller:**

```bash
cd jenkins/controller
docker-compose up -d
```

Access Jenkins at `http://<server-ip>:8080`. Retrieve the initial admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

2. **Install required plugins:**

   From *Manage Jenkins > Plugins*, install:
   - **Docker Pipeline** — for building and pushing Docker images
   - **SSH Agent** — for SSH-based deployment to EC2
   - **Slack Notification** — for build status alerts to the `#weather-jenkins` channel

3. **Connect a build agent:**

Update `<JENKINS_CONTROLLER_IP>` and `<JENKINS_AGENT_SECRET>` in `jenkins/agent/docker-compose.yml`, then:

```bash
cd jenkins/agent
docker-compose up -d
```

The agent secret is generated by Jenkins when you create a new node under *Manage Jenkins > Nodes*.

Alternatively, use `agent.sh` to register the agent as a systemd service.

4. **Configure Jenkins credentials:**

   Add the following under *Manage Jenkins > Credentials*:
   - `dockerhub-creds` (Username with password) — Docker Hub account for image push
   - `ec2-ssh-key` (SSH Username with private key) — SSH key for deployment to the app EC2 instance

### Pipeline Stages

The `jenkins/Jenkinsfile` defines a 7-stage pipeline:

| Stage | Description |
|-------|-------------|
| **Install Dependencies** | `pip install -r requirements.txt` |
| **Pylint** | Code quality gate (minimum score: 5.0) |
| **Unittest** | Runs `python3 -m unittest tests.py` |
| **Build Docker Image** | Builds `yevgenio/weatherapp:latest` |
| **Test Docker Image** | Spins up container, health-checks port 8080 |
| **Push to Docker Hub** | Authenticates and pushes the image |
| **Deploy to App EC2** | SCPs compose files, runs `docker-compose up -d` on the target EC2 |

Post-build notifications are sent to a `#weather-jenkins` Slack channel on success or failure.

## GitLab Setup

Deploy a self-hosted GitLab CE instance:

```bash
cd gitlab
mkdir config logs data
```

> [!NOTE]
> Update `<GITLAB_SERVER_IP>` in `docker-compose.yml` to match your server's IP or domain before starting.

```bash
docker-compose up -d
```

Access GitLab at `http://<server-ip>:80`. The initial root password can be retrieved with:

```bash
docker exec gitlab cat /etc/gitlab/initial_root_password
```

GitLab SSH is available on port **2424** (to avoid conflict with the host SSH on port 22).

## Kubernetes Deployment

To deploy the weather app on the EKS cluster:

```bash
# Configure kubectl for the EKS cluster
aws eks update-kubeconfig --name dev-eks --region us-east-1

# Deploy the application
kubectl apply -f kubernetes/weatherapp.yaml
```

This creates a 2-replica Deployment exposed via a NodePort Service on port 30080, accessible through the ALB at `eks.source-code.click`.

Verify the deployment:

```bash
kubectl get pods -l app=weatherapp
kubectl get svc weatherapp
```

## Monitoring

The application exposes Prometheus metrics at the `/metrics` endpoint:

- `home_visit_total` — Counter for homepage visits
- `result_returned_total` — Counter for forecast results served
- `api_call_duration_seconds` — Summary of weather API call latency
