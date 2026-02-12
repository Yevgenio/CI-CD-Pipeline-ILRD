output "alb_id" {
  description = "ALB ID"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route53 alias)"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "target_group_arns" {
  description = "Map of target group ARNs"
  value = {
    gitlab  = aws_lb_target_group.gitlab.arn
    jenkins = aws_lb_target_group.jenkins.arn
    agent   = aws_lb_target_group.agent.arn
    eks_app = aws_lb_target_group.eks_app.arn
  }
}
