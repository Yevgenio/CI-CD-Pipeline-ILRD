provider "aws" {
  region = "us-east-1"
}

# vpc Module
module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway

  cluster_name = var.cluster_name

  tags = {
    Owner = "Yevgeni"
    Cost  = "${var.environment}-environment"
  }
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  tags = {
    Owner = "Yevgeni"
    Cost  = "${var.environment}-environment"
  }
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Owner = "Yevgeni"
    Cost  = "${var.environment}-environment"
  }
}

# DNS Module (Route53 + ACM Certificate + Internal DNS)
module "dns" {
  source = "../../modules/dns"

  domain_name        = var.domain_name
  environment        = var.environment
  create_alb_records = true
  alb_dns_name       = module.alb.alb_dns_name
  alb_zone_id        = module.alb.alb_zone_id
  subdomains         = ["app", "gitlab", "jenkins", "agent", "eks"]

  # Private hosted zone for internal DNS
  vpc_id = module.vpc.vpc_id
  internal_records = module.compute.single_az_instance_ips

  tags = {
    Owner = "Yevgeni"
    Cost  = "${var.environment}-environment"
  }
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  certificate_arn     = module.dns.certificate_validated_arn
  domain_name         = var.domain_name
  gitlab_instance_id  = module.compute.gitlab_instance_id
  jenkins_instance_id = module.compute.jenkins_controller_instance_id
  agent_instance_id   = module.compute.jenkins_agent_instance_id

  # EKS NodePort target group
  eks_node_group_asg_name = module.eks.node_group_asg_name

  tags = {
    Owner = "Yevgeni"
    Cost  = "${var.environment}-environment"
  }
}

# Allow ALB to reach EKS nodes on the NodePort
resource "aws_security_group_rule" "alb_to_eks_nodes" {
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
}
