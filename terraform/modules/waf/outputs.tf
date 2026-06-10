output "waf_arn" {
  description = "Ingress에 사용할 WAF ARN"
  value       = aws_wafv2_web_acl.waf.arn
}
