# Outputs
output "single_az_instance_ips" {
  description = "Private IPs of single AZ instances"
  value       = { for k, v in aws_instance.single_az : k => v.private_ip }
}

output "all_instance_ids" {
  description = "All instance IDs"
  value       = { for k, v in aws_instance.single_az : k => v.id }
}

output "gitlab_instance_id" {
  description = "GitLab instance ID"
  value       = aws_instance.single_az["gitlab"].id
}

output "jenkins_controller_instance_id" {
  description = "Jenkins controller instance ID"
  value       = aws_instance.single_az["jenkins-controller"].id
}

output "jenkins_agent_instance_id" {
  description = "Jenkins agent instance ID"
  value       = aws_instance.single_az["jenkins-agent"].id
}

output "security_group_id" {
  description = "Compute security group ID"
  value       = aws_security_group.my_sg.id
}
