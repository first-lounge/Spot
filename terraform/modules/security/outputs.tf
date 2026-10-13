output "nat_instance_sg_id" {
  value = var.enable_nat_instance ? aws_security_group.nat_instance_sg[0].id : null
}

output "node_group_sg_id" {
  value = aws_security_group.eks_node_sg.id
}

output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}

output "elasticache_sg_id" {
  value = aws_security_group.elasticache_sg.id
}

output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "node_group_role_arn" {
  value = aws_iam_role.eks_nodegroup.arn
}
