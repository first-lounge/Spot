# =============================================================================
# Route 53 Hosted Zone
# =============================================================================

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# =============================================================================
# ALB와 도메인 연결
# =============================================================================
data "aws_alb" "ingress_alb" {
  tags = {
    Name        = "spot-alb",
    Environment = var.environment
  }
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name    = data.aws_alb.ingress_alb.dns_name
    zone_id = data.aws_alb.ingress_alb.zone_id

    # ALB 자체 헬스체크가 있어서 Route53 헬스체크 중복 불필요
    # true로 설정 시 추가 비용 발생
    evaluate_target_health = false
  }
}
