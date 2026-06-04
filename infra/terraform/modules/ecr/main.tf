# =============================================================================
# ECR Repository
# =============================================================================

resource "aws_ecr_repository" "services" {
  for_each = var.services_name

  name                 = "${var.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true # 테스트 진행할 때만 사용

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
