# =============================================================================
# EKS Cluster
# =============================================================================
resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs # 외부 접근을 특정 IP로 제한
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-eks-cluster" })
}

resource "aws_eks_access_entry" "master" {
  cluster_name  = aws_eks_cluster.cluster.name
  principal_arn = var.admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "master" {
  cluster_name  = aws_eks_cluster.cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.admin_role_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.master]
}

# =============================================================================
# Launch Template
# =============================================================================
resource "aws_launch_template" "eks_node" {
  name_prefix = "${var.name_prefix}-eks-node-"
  vpc_security_group_ids = [
    var.node_group_sg_id,
    aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  ]

  # EBS 설정 (볼륨 크기, 암호화)
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_arn
      delete_on_termination = true
    }
  }

  # IMDSv2 강제 (보안)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # 노드에 Name 태그 부여 (콘솔에서 식별용)
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.name_prefix}-eks-node"
    })
  }

  # EBS에 Name 태그 부여
  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      Name = "${var.name_prefix}-eks-volume"
    })
  }
}

# =============================================================================
# EKS Node Group (Dev는 1개, Prod는 4개)
# =============================================================================
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = var.cluster_name
  node_group_name = "${var.name_prefix}-${each.key}-node-group"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.node_subnet_ids
  depends_on      = [aws_eks_cluster.cluster]

  capacity_type  = each.value.capacity_type # Dev=SPOT, Prod= SPOT + ON_DEMAND
  instance_types = var.instance_types

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  labels = {
    environment = var.environment
    workload    = each.value.workload
  }

  launch_template {
    id      = aws_launch_template.eks_node.id
    version = aws_launch_template.eks_node.latest_version
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-node-group"
  })
}

# =============================================================================
# EKS Addon
# =============================================================================
locals {
  has_etc_group = contains(keys(var.node_groups), "etc")
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"

  # AWS 기본 버전 자동 설치
  addon_version               = var.vpc_cni_version != "" ? var.vpc_cni_version : null
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_cluster.cluster]
  tags                        = merge(var.common_tags, { Name = "${var.name_prefix}-vpc-cni" })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version != "" ? var.kube_proxy_version : null
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_cluster.cluster]
  tags                        = merge(var.common_tags, { Name = "${var.name_prefix}-kube-proxy" })
}

resource "aws_eks_addon" "core_dns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = var.core_dns_version != "" ? var.core_dns_version : null
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = local.has_etc_group ? jsonencode({
    replicaCount = 2
    nodeSelector = {
      workload = "etc"
    }
    topologySpreadConstraints = [
      {
        maxSkew           = 1,
        topologyKey       = "topology.kubernetes.io/zone",
        whenUnsatisfiable = "ScheduleAnyway",
        labelSelector     = { matchLabels = { k8s-app = "kube-dns" } }
      }
    ]

  }) : null

  depends_on = [aws_eks_cluster.cluster]
  tags       = merge(var.common_tags, { Name = "${var.name_prefix}-core-dns" })
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_version != "" ? var.ebs_csi_version : null
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.irsa["ebs_csi"].arn

  configuration_values = local.has_etc_group ? jsonencode({
    controller = {
      replicaCount = 2
      nodeSelector = {
        workload = "etc"
      }
      topologySpreadConstraints = [
        {
          maxSkew           = 1,
          topologyKey       = "topology.kubernetes.io/zone",
          whenUnsatisfiable = "ScheduleAnyway",
          labelSelector     = { matchLabels = { app = "ebs-csi-controller" } }
        }
      ]
    }
  }) : null

  depends_on = [aws_eks_cluster.cluster]
  tags       = merge(var.common_tags, { Name = "${var.name_prefix}-ebs-csi" })
}
