# Environment Configuration
environment = "dev"
domain_name = "source-code.click"

# Network Settings
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Cost optimization - single NAT for dev, set false for prod HA
single_nat_gateway = true

# EKS configuration
cluster_name        = "dev-eks"
cluster_version     = "1.35"
node_instance_types = ["t3.medium"]
node_min_size       = 2
node_max_size       = 4
node_desired_size   = 2

