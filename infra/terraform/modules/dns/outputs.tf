output "zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_name" {
  description = "Route 53 Hosted Zone 이름"
  value       = aws_route53_zone.main.name
}

output "name_servers" {
  description = "Route 53 네임서버 목록 (도메인 등록 기관에 설정 필요)"
  value       = aws_route53_zone.main.name_servers
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