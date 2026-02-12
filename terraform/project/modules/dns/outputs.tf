output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name"
  value       = data.aws_route53_zone.main.name
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.main.arn
}

output "certificate_validated_arn" {
  description = "ACM certificate ARN (after validation)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
