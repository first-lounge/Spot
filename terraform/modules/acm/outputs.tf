output "aws_acm_certificate_arn" {
  description = "ACM 인증서 ARN (ALB HTTPS 리스너 연결용)"
  value       = aws_acm_certificate.acm_cert.arn
}
