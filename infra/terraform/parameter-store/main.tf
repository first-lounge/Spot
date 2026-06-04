# =============================================================================
# Parameter Store Module
# =============================================================================

locals {
  prefix = "/${var.project}/${var.environment}"
}

# =============================================================================
# 민감 정보 Parameters (SecureString)
# =============================================================================
resource "aws_ssm_parameter" "db_password" {
  name        = "${local.prefix}/database/password"
  description = "Database password"
  type        = "SecureString"
  value       = var.db_password

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-password"
    Category = "database"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "${local.prefix}/secrets/jwt_secret"
  description = "JWT secret key"
  type        = "SecureString"
  value       = var.jwt_secret

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-jwt-secret"
    Category = "secrets"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "mail_password" {
  count = var.mail_password != "" ? 1 : 0

  name        = "${local.prefix}/secrets/mail_password"
  description = "SMTP password"
  type        = "SecureString"
  value       = var.mail_password

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-mail-password"
    Category = "secrets"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "toss_secret_key" {
  count = var.toss_secret_key != "" ? 1 : 0

  name        = "${local.prefix}/secrets/toss_secret_key"
  description = "Toss Payments secret key"
  type        = "SecureString"
  value       = var.toss_secret_key

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-toss-secret-key"
    Category = "secrets"
    Type     = "secret"
  })
}

# =============================================================================
# 동적 인프라 값 Parameters (String)
# =============================================================================
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "${local.prefix}/database/endpoint"
  description = "RDS endpoint (auto-populated by Terraform)"
  type        = "String"
  value       = var.db_endpoint

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-endpoint"
    Category = "database"
    Type     = "infrastructure"
  })
}

resource "aws_ssm_parameter" "redis_endpoint" {
  count = var.redis_endpoint != "" ? 1 : 0

  name        = "${local.prefix}/cache/redis_endpoint"
  description = "Redis endpoint (auto-populated by Terraform)"
  type        = "String"
  value       = var.redis_endpoint

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-redis-endpoint"
    Category = "cache"
    Type     = "infrastructure"
  })
}
