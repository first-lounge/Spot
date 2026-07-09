output "github_oidc_role_arn" {
  description = "GitHub OIDC Role ARN"
  value       = aws_iam_role.github_oidc.arn
}
