variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "gitlab_instance_id" {
  description = "GitLab instance ID"
  type        = string
}

variable "jenkins_instance_id" {
  description = "Jenkins controller instance ID"
  type        = string
}

variable "agent_instance_id" {
  description = "Jenkins agent instance ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name for host-based routing"
  type        = string
}

variable "eks_node_group_asg_name" {
  description = "EKS node group Auto Scaling Group name for target group attachment"
  type        = string
}

variable "eks_app_node_port" {
  description = "NodePort on EKS nodes for the weatherapp service"
  type        = number
  default     = 30080
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
