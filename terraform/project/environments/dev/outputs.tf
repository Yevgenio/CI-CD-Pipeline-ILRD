# Root outputs - expose module outputs for visibility

# vpc outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT gateways"
  value       = module.vpc.nat_gateway_public_ips
}

# Compute outputs
output "single_az_instance_ips" {
  description = "Private IPs of single AZ instances"
  value       = module.compute.single_az_instance_ips
}

output "all_instance_ids" {
  description = "All EC2 instance IDs"
  value       = module.compute.all_instance_ids
}

# DNS outputs
output "zone_id" {
  description = "Route53 hosted zone ID (existing)"
  value       = module.dns.zone_id
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.dns.certificate_arn
}

# ALB outputs
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "app_url" {
  description = "WeatherApp URL"
  value       = "https://app.${var.domain_name}"
}

output "gitlab_url" {
  description = "GitLab URL"
  value       = "https://gitlab.${var.domain_name}"
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "https://jenkins.${var.domain_name}"
}

output "agent_url" {
  description = "Jenkins Agent URL"
  value       = "https://agent.${var.domain_name}"
}

# EKS outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_app_url" {
  description = "EKS WeatherApp URL"
  value       = "https://eks.${var.domain_name}"
}
