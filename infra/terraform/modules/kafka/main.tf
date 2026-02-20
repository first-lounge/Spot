# =============================================================================
# Kafka EC2 Module (KRaft Mode - Single/Multi Broker)
# =============================================================================
locals {
  kafka_port    = 9092
  kraft_port    = 9093
  internal_port = 9094

  effective_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : (var.subnet_id != null ? [var.subnet_id] : [])
  single_subnet        = length(local.effective_subnet_ids) <= 1

  brokers = var.broker_count > 1 ? (
    local.single_subnet ? {
    "1" = { subnet_index = 0, az_suffix = "a" }
    "2" = { subnet_index = 0, az_suffix = "a" }
    "3" = { subnet_index = 0, az_suffix = "a" }
  } : {
    "1" = { subnet_index = 0, az_suffix = "a" }
    "2" = { subnet_index = 1, az_suffix = "c" }
    "3" = { subnet_index = 1, az_suffix = "c" }
  }
  ) : {
    "1" = { subnet_index = 0, az_suffix = "a" }
  }
}

# =============================================================================
# Security Group
# =============================================================================
resource "aws_security_group" "kafka" {
  name   = "${var.name_prefix}-kafka-sg"
  vpc_id = var.vpc_id

  # Kafka 클라이언트 포트 (EKS에서 접근)
  ingress {
    from_port       = local.kafka_port
    to_port         = local.kafka_port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  # 브로커 간 클라이언트 통신 (replication)
  ingress {
    from_port = local.kafka_port
    to_port   = local.kafka_port
    protocol  = "tcp"
    self      = true
  }

  # KRaft Controller 포트 (브로커 간 controller 통신)
  ingress {
    from_port = local.kraft_port
    to_port   = local.kraft_port
    protocol  = "tcp"
    self      = true
  }

  # Internal 리스너 (브로커 간 복제 통신)
  ingress {
    from_port = local.internal_port
    to_port   = local.internal_port
    protocol  = "tcp"
    self      = true
  }

  # SSH (디버깅용 - 선택적)
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-kafka-sg" })
}

# =============================================================================
# IAM Role (CloudWatch Logs, SSM 등)
# =============================================================================
resource "aws_iam_role" "kafka" {
  name = "${var.name_prefix}-kafka-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "kafka_ssm" {
  role       = aws_iam_role.kafka.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "kafka_cloudwatch" {
  role       = aws_iam_role.kafka.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "kafka" {
  name = "${var.name_prefix}-kafka-profile"
  role = aws_iam_role.kafka.name
}

# =============================================================================
# EC2 Instances (Multi-Broker Support)
# =============================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "kafka" {
  for_each = local.brokers

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = local.effective_subnet_ids[each.value.subnet_index]
  vpc_security_group_ids = [aws_security_group.kafka.id]
  iam_instance_profile   = aws_iam_instance_profile.kafka.name

  associate_public_ip_address = var.assign_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = var.delete_on_termination
    encrypted             = true
  }

  user_data = base64encode(templatefile(
      var.broker_count > 1 ? "${path.module}/user-data-cluster.sh" : "${path.module}/user-data.sh",
    {
      kafka_version       = var.kafka_version
      kafka_cluster_id    = var.cluster_id
      kafka_broker_host   = "${var.name_prefix}-kafka-${each.key}"
      kafka_port          = local.kafka_port
      kraft_port          = local.kraft_port
      internal_port       = local.internal_port
      log_retention_hours = var.log_retention_hours
      log_retention_gb    = var.log_retention_gb
      node_id             = each.key
      broker_count        = var.broker_count
    }
  ))

  tags = merge(var.common_tags, {
    Name     = "${var.name_prefix}-kafka-${each.key}"
    BrokerId = each.key
    AZ       = each.value.az_suffix
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}


# =============================================================================
# Route53 Private DNS (서비스 디스커버리용)
# =============================================================================
resource "aws_route53_zone" "kafka" {
  count = var.create_private_dns ? 1 : 0

  name = "${var.name_prefix}.kafka.internal"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-kafka-zone" })
}

resource "aws_route53_record" "kafka_brokers" {
  for_each = var.create_private_dns ? local.brokers : {}

  zone_id = aws_route53_zone.kafka[0].zone_id
  name    = "kafka-${each.key}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.kafka[each.key].private_ip]
}

resource "aws_route53_record" "kafka_bootstrap" {
  count = var.create_private_dns ? 1 : 0

  zone_id = aws_route53_zone.kafka[0].zone_id
  name    = "bootstrap"
  type    = "A"
  ttl     = 60
  records = [for k, v in aws_instance.kafka : v.private_ip]
}