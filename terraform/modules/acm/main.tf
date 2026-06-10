# =============================================================================
# ACM Certificate (인증서 발급)
# =============================================================================
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-acm-cert" })
}

# =============================================================================
# ACM DNS Validation Records (검증용 DNS 레코드 생성)
# =============================================================================
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# =============================================================================
# ACM Certificate Validation (검증 단계)
# =============================================================================
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}
