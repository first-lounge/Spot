output "bucket_name" {
  description = "S3 버킷 이름"
  value       = module.s3.bucket_name
}

output "acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = module.acm.aws_acm_certificate_arn
}

output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = module.rds.rds_endpoint
}

output "redis_primary_endpoint" {
  description = "Redis 쓰기용 엔드포인트"
  value       = module.redis.redis_primary_endpoint
}

output "waf_acl_arn" {
  description = "ALB Ingress에 연결할 WAF ARN"
  value       = module.waf.waf_arn
}
