variable "domain_name" {
  description = "The domain name (e.g., source-code.click)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "create_alb_records" {
  description = "Whether to create DNS records for ALB"
  type        = bool
  default     = true
}

variable "alb_dns_name" {
  description = "ALB DNS name for alias records"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID for alias records"
  type        = string
  default     = ""
}

variable "subdomains" {
  description = "List of subdomains to create (pointing to ALB)"
  type        = list(string)
  default     = ["app", "gitlab", "jenkins", "agent"]
}

variable "vpc_id" {
  description = "VPC ID for private hosted zone"
  type        = string
  default     = ""
}

variable "internal_records" {
  description = "Map of internal hostnames to private IPs"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
