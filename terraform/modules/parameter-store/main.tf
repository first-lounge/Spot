# =============================================================================
# Parameter Store 
# =============================================================================
locals {
  prefix = "/${var.project}/${var.environment}"
}

# 민감 정보(SecureString)
resource "aws_ssm_parameter" "rds_username" {
  description = "Database username"
  name        = "${local.prefix}/database/username"
  type        = "SecureString"
  value       = var.rds_username

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-username"
    Category = "database"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "rds_password" {
  count = var.enable_rds_secret ? 0 : 1

  description = "Database password"
  name        = "${local.prefix}/database/password"
  type        = "SecureString"
  value       = var.rds_password

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-password"
    Category = "database"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "jwt_secret" {
  description = "JWT secret key"
  name        = "${local.prefix}/jwt/secret"
  type        = "SecureString"
  value       = var.jwt_secret

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-jwt-secret"
    Category = "jwt"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "mail_username" {
  description = "SMTP username"
  name        = "${local.prefix}/mail/username"
  type        = "SecureString"
  value       = var.mail_username

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-mail-username"
    Category = "mail"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "mail_password" {
  description = "SMTP password"
  name        = "${local.prefix}/mail/password"
  type        = "SecureString"
  value       = var.mail_password

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-mail-password"
    Category = "mail"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "toss_secret_key" {
  description = "Toss Payments secret key"
  name        = "${local.prefix}/toss/secret_key"
  type        = "SecureString"
  value       = var.toss_secret_key

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-toss-secret-key"
    Category = "toss"
    Type     = "secret"
  })
}

# =============================================================================
# 동적 인프라 값 (String)
#  =============================================================================
resource "aws_ssm_parameter" "rds_host" {
  for_each = var.rds_host

  description = "RDS Host (auto-populated by Terraform)"
  name        = "${local.prefix}/database/${each.key}/host"
  type        = "String"
  value       = each.value

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-${each.key}-rds-host"
    Category = "database"
    Type     = "infrastructure"
  })
}

resource "aws_ssm_parameter" "rds_service_url" {
  for_each = var.services

  description = "RDS URL for spot-${each.key}"
  name        = "${local.prefix}/database/${each.key}/url"
  type        = "String"
  value       = "jdbc:postgresql://${var.rds_host[each.key]}:5432/spot_${each.key}"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-${each.key}-rds-url"
    Category = "database"
    Type     = "infrastructure"
  })
}

resource "aws_ssm_parameter" "elasticache_endpoint" {
  description = "Redis endpoint (auto-populated by Terraform)"
  name        = "${local.prefix}/cache/redis_endpoint"
  type        = "String"
  value       = var.elasticache_endpoint

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-elasticache-endpoint"
    Category = "cache"
    Type     = "infrastructure"
  })
}

resource "aws_ssm_parameter" "elasticache_password" {
  count = var.enable_elasticache_auth ? 1 : 0

  description = "ElastiCache Password"
  name        = "${local.prefix}/cache/redis_password"
  type        = "SecureString"
  value       = var.elasticache_password # 운영 전환 시 삭제

  # # 운영 전환 시
  # value_wo         = var.elasticache_password
  # value_wo_version = var.elasticache_password_version

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-elasticache-password"
    Category = "cache"
    Type     = "secret"
  })
}
