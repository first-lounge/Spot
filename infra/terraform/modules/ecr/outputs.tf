output "ecr_repository_arns" {
  description = "ECR 레포지토리 ARN 목록"
  value       = { for k, v in aws_ecr_repository.services : k => v.arn }
}

output "ecr_repository_uris" {
  description = "ECR 레포지토리 URI 목록"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "repository_names" {
  description = "ECR 레포지토리 이름 목록"
  value       = { for k, v in aws_ecr_repository.services : k => v.name }
}
