# =============================================================================
# Route 53 Hosted Zone
# =============================================================================
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-zone" })
}

# =============================================================================
# ACM Certificate
# =============================================================================
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-cert" })
}

# =============================================================================
# ACM DNS Validation Records
# =============================================================================
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

# =============================================================================
# ACM Certificate Validation
# =============================================================================
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}


# =============================================================================
# EKS(ALB) Record
# =============================================================================
resource "aws_route53_record" "alb" {
  count = var.create_alb_record ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.alb_record_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = false
  }
}
