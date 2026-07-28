# =============================================================================
# Parameter Name Prefix (for wildcard IAM policies)
# =============================================================================
output "parameter_prefix" {
  description = "Parameter Store prefix (EKS IRSA/IAM wildcard policy에서 사용)"
  value       = "/${var.project}/${var.environment}"
}
