# =============================================================================
# Route53 Hosted Zone
# =============================================================================
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = merge(var.common_tags, { Name = "${var.name_prefix}-zone" })
}

# =============================================================================
# ALB와 도메인 연결
# =============================================================================
resource "aws_route53_record" "alb" {
  count   = var.alb_dns_name != "" ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name    = var.alb_dns_name
    zone_id = "ZWKZPGTI48KDX"

    # ALB 자체 헬스체크가 있어서 Route53 헬스체크 중복 불필요
    # true로 설정 시 추가 비용 발생
    evaluate_target_health = false
  }
}
