# =============================================================================
# ECR Repository
# =============================================================================
resource "aws_ecr_repository" "kafka" {
  name                 = "spot-kafka-connect"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true # Dev, Prod 모두 사용, 운영 전환 시 false로 변경

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-ecr-kafka"
    Service = "kafka-connect"
  })
}

resource "aws_ecr_repository" "services" {
  for_each = var.services_name

  name                 = "spot-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true # Dev, Prod 모두 사용, 운영 전환 시 false로 변경

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-ecr-${each.key}"
    Service = each.key
  })
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each = var.services_name

  repository = aws_ecr_repository.services[each.key].name
  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last ${var.image_retention_count} images",
      selection = {
        tagStatus   = "any",
        countType   = "imageCountMoreThan",
        countNumber = var.image_retention_count
      },
      action = {
        type = "expire"
      }
    }]
  })
}
