# =============================================================================
# 보안 그룹 (SG)
# =============================================================================

# EKS 노드 (Private)
resource "aws_security_group" "eks_node_sg" {
  name   = "${var.name_prefix}-eks-node-sg"
  vpc_id = var.vpc_id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-eks-node-sg" })
}

# RDS (Private)
resource "aws_security_group" "rds_sg" {
  name   = "${var.name_prefix}-rds-sg"
  vpc_id = var.vpc_id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-rds-sg" })
}

# Redis (Private)
resource "aws_security_group" "redis_sg" {
  name   = "${var.name_prefix}-redis-sg"
  vpc_id = var.vpc_id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-redis-sg" })
}

# ALB (Public)
resource "aws_security_group" "alb_sg" {
  name   = "${var.name_prefix}-alb-sg"
  vpc_id = var.vpc_id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-alb-sg" })
}

# NAT Instance
resource "aws_security_group" "nat_sg" {
  count = var.enable_nat_instance ? 1 : 0

  name   = "${var.name_prefix}-nat-sg"
  vpc_id = var.vpc_id
  tags   = merge(var.common_tags, { Name = "${var.name_prefix}-nat-sg" })
}

# =============================================================================
# 보안 그룹 규칙
# =============================================================================

# -------- ALB --------

# ALB ← HTTP
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

# ALB ← HTTPS
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

# ALB → EKS 노드
resource "aws_security_group_rule" "alb_egress_node" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node_sg.id
  security_group_id        = aws_security_group.alb_sg.id
}

# -------- NAT Instance --------

# NAT Instance ← VPC
resource "aws_security_group_rule" "nat_ingress_vpc" {
  count = var.enable_nat_instance ? 1 : 0

  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.nat_sg[0].id
}

# NAT Instance ← IGW
resource "aws_security_group_rule" "nat_egress_igw" {
  count = var.enable_nat_instance ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nat_sg[0].id
}

# -------- EKS Node Group --------

# EKS Node ← ALB 
resource "aws_security_group_rule" "node_ingress_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.eks_node_sg.id
}

# Pod 간 통신 
resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_node_sg.id
}

# EKS Node → AWS 서비스 & EKS Cluster
resource "aws_security_group_rule" "node_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # 모든 트래픽 허용
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_sg.id
}

# -------- RDS --------

# RDS ← EKS Node
resource "aws_security_group_rule" "rds_ingress_node" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}

# -------- Redis --------

# Redis ← EKS Node
resource "aws_security_group_rule" "redis_ingress_node" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node_sg.id
  security_group_id        = aws_security_group.redis_sg.id
}

# =============================================================================
# IAM
# =============================================================================

# EKS 클러스터
resource "aws_iam_role" "eks_cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-eks-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# EKS 노드
resource "aws_iam_role" "eks_nodegroup" {
  name = "${var.name_prefix}-eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-eks-nodegroup-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup.name
}
