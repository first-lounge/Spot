output "zone_id" {
  value = local.zone_id
}

output "zone_name" {
  value = var.domain_name
}

output "name_servers" {
  value = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}

output "certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

# ALB 레코드 FQDN
output "alb_record_fqdn" {
  description = "ALB Alias 레코드 FQDN"
  value       = var.create_alb_record ? aws_route53_record.alb[0].fqdn : null
}