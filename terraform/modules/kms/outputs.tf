output "ebs_kms_arn" {
  value = aws_kms_key.ebs.arn
}

output "rds_kms_arn" {
  value = aws_kms_key.rds.arn
}
