# =============================================================================
# Parameter Store 
# =============================================================================
locals {
  prefix = "/${var.project}/${var.environment}"
}

# 민감 정보(SecureString)
resource "aws_ssm_parameter" "db_username" {
  name        = "${local.prefix}/database/username"
  type        = "SecureString"
  value       = var.db_username
  description = "Database username"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-username"
    Category = "database"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "db_password" {
  name        = "${local.prefix}/database/password"
  type        = "SecureString"
  value       = var.db_password
  description = "Database password"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-password"
    Category = "database"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "${local.prefix}/jwt/secret"
  type        = "SecureString"
  value       = var.jwt_secret
  description = "JWT secret key"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-jwt-secret"
    Category = "jwt"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "mail_username" {
  name        = "${local.prefix}/mail/username"
  type        = "SecureString"
  value       = var.mail_username
  description = "SMTP username"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-mail-username"
    Category = "mail"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "mail_password" {
  name        = "${local.prefix}/mail/password"
  type        = "SecureString"
  value       = var.mail_password
  description = "SMTP password"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-mail-password"
    Category = "mail"
    Type     = "secret"
  })
}

resource "aws_ssm_parameter" "toss_secret_key" {
  name        = "${local.prefix}/toss/secret_key"
  type        = "SecureString"
  value       = var.toss_secret_key
  description = "Toss Payments secret key"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-toss-secret-key"
    Category = "toss"
    Type     = "secret"
  })
}

# =============================================================================
# 동적 인프라 값 (String)
#  =============================================================================
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "${local.prefix}/database/endpoint"
  type        = "String"
  value       = var.db_endpoint
  description = "RDS endpoint (auto-populated by Terraform)"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-endpoint"
    Category = "database"
    Type     = "infrastructure"
  })
}

resource "aws_ssm_parameter" "db_url" {
  name        = "${local.prefix}/database/url"
  type        = "String"
  description = "RDS URL"
  value       = "jdbc:postgresql://${var.db_endpoint}:5432/spot_db"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-db-url"
    Category = "database"
    Type     = "infrastructure"
  })
}

resource "aws_ssm_parameter" "redis_endpoint" {
  name        = "${local.prefix}/cache/redis_endpoint"
  type        = "String"
  value       = var.redis_endpoint
  description = "Redis endpoint (auto-populated by Terraform)"

  tags = merge(var.common_tags, {
    Name     = "${var.project}-${var.environment}-redis-endpoint"
    Category = "cache"
    Type     = "infrastructure"
  })
}
