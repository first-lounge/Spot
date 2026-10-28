# =============================================================================
# RDS
# =============================================================================
locals {
  gib = 1024 * 1024 * 1024

  free_storage_threshold = floor(var.rds_allocated_storage * local.gib * var.rds_thresholds.free_storage_ratio)

  connection_threshold = floor(var.rds_max_connection * var.rds_thresholds.rds_connection_ratio)

  cdc_target        = { for k, v in var.rds_instances : k => v if v.cdc == true }
  slot_lag_warning  = floor(var.slot_lag_thresholds.warning * local.gib)
  slot_lag_critical = floor(var.slot_lag_thresholds.critical * local.gib)
}

# CPUUtilization
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each = var.rds_identifiers

  alarm_name          = "${each.value}-cpu"
  alarm_description   = "${each.value} CPU 사용률 ${var.rds_thresholds.cpu_percent}% 초과 (15분 지속)"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.rds_thresholds.cpu_percent
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${each.value}-cpu" })
}

# FreeStorageSpace
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  for_each = var.rds_identifiers

  alarm_name          = "${each.value}-free-storage"
  alarm_description   = "${each.value} 남은 디스크 ${var.rds_thresholds.free_storage_ratio * 100}% 미만"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = local.free_storage_threshold
  comparison_operator = "LessThanThreshold"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${each.value}-free-storage" })
}

# DatabaseConnections
resource "aws_cloudwatch_metric_alarm" "rds_connection" {
  for_each = var.rds_identifiers

  alarm_name          = "${each.value}-connection"
  alarm_description   = "${each.value} 커넥션 ${var.rds_thresholds.rds_connection_ratio * 100}% 초과"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBInstanceIdentifier = each.value }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3 # 최근 몇 개를 볼지
  datapoints_to_alarm = 2 # 그중 몇 개가 넘으면 알람인지
  threshold           = local.connection_threshold
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${each.value}-connection" })
}

# OldestReplicationSlotLag
resource "aws_cloudwatch_metric_alarm" "slot_lag_warning" {
  for_each = local.cdc_target

  alarm_name          = "${var.name_prefix}-${each.key}-slot-lag-warning"
  alarm_description   = "${var.name_prefix}-${each.key} 복제 slot ${var.slot_lag_thresholds.warning}GiB 초과"
  namespace           = "AWS/RDS"
  metric_name         = "OldestReplicationSlotLag"
  dimensions          = { DBInstanceIdentifier = var.rds_identifiers[each.key] }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = local.slot_lag_warning
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}-slot-lag-warning" })
}

resource "aws_cloudwatch_metric_alarm" "slot_lag_critical" {
  for_each = local.cdc_target

  alarm_name          = "${var.name_prefix}-${each.key}-slot-lag-critical"
  alarm_description   = "${var.name_prefix}-${each.key} 복제 slot ${var.slot_lag_thresholds.critical}GiB 초과"
  namespace           = "AWS/RDS"
  metric_name         = "OldestReplicationSlotLag"
  dimensions          = { DBInstanceIdentifier = var.rds_identifiers[each.key] }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = local.slot_lag_critical
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching" # 데이터가 안 들어온 시간을 어떻게 볼지 결정

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}-slot-lag-critical" })
}

# =============================================================================
# ElastiCache
# =============================================================================

# Database Memory Usage Percentage
resource "aws_cloudwatch_metric_alarm" "elasticache_mem_usage" {
  for_each = var.elasticache_ids

  alarm_name          = "${each.value}-mem-usage"
  alarm_description   = "${each.value} 메모리 사용량 ${var.elasticache_thresholds.mem_usage}% 초과"
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  dimensions          = { CacheClusterId = each.value }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.elasticache_thresholds.mem_usage
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${each.value}-mem-usage" })
}

# Eviction
resource "aws_cloudwatch_metric_alarm" "elasticache_eviction" {
  for_each = var.elasticache_ids

  alarm_name          = "${each.value}-eviction"
  alarm_description   = "${each.value} Eviction ${var.elasticache_thresholds.evictions}건 초과 (메모리 부족으로 키 강제 삭제)"
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  dimensions          = { CacheClusterId = each.value }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = var.elasticache_thresholds.evictions
  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${each.value}-eviction" })
}

# =============================================================================
# ALB
# =============================================================================

data "aws_lbs" "alb_list" {
  tags = {
    Name        = "${var.name_prefix}-alb",
    Environment = var.common_tags["Environment"]
  }
}

data "aws_lb" "alb" {
  count = length(data.aws_lbs.alb_list.arns) > 0 ? 1 : 0

  arn = one(data.aws_lbs.alb_list.arns)
}

data "aws_lb_target_group" "target_group" {
  count = length(data.aws_lbs.alb_list.arns) > 0 ? 1 : 0

  tags = { "ingress.k8s.aws/resource" = "spot/spot-ing-spot-gateway:80" }
}

# Target에서 생성된 5XX 응답 개수
resource "aws_cloudwatch_metric_alarm" "httpcode_target_count" {
  count = length(data.aws_lbs.alb_list.arns) > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-target-5xx-count"
  alarm_description   = "Spot-Gateway의 5XX 응답 개수"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = data.aws_lb.alb[0].arn_suffix, TargetGroup = data.aws_lb_target_group.target_group[0].arn_suffix }
  statistic           = "Sum"
  period              = 180
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-target-5xx-count" })
}

# ALB 헬스체크 기준으로 unhealthy 판정을 받은 Target 개수
resource "aws_cloudwatch_metric_alarm" "unhealthy_host_count" {
  count = length(data.aws_lbs.alb_list.arns) > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-unhealthy-host-count"
  alarm_description   = "UnHealthy 판정을 받은 Target 개수"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = data.aws_lb.alb[0].arn_suffix, TargetGroup = data.aws_lb_target_group.target_group[0].arn_suffix }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2 # 최근 몇 개를 볼지
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-unhealthy-host-count" })
}

# ALB가 요청을 넘긴 후 gateway가 응답을 시작할 때까지 걸린 시간(p95, 초)
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  count = length(data.aws_lbs.alb_list.arns) > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-target-response-time"
  alarm_description   = "ALB가 요청을 넘긴 후 gateway가 응답을 시작할 때까지 걸린 시간(p95, 초)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = data.aws_lb.alb[0].arn_suffix, TargetGroup = data.aws_lb_target_group.target_group[0].arn_suffix }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 5
  threshold           = 2 # 초 (부하테스트 후 재조정)
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-target-response-time" })
}

# ALB HTTP 5XX 서버 오류 개수
resource "aws_cloudwatch_metric_alarm" "httpcode_elb_count" {
  count = length(data.aws_lbs.alb_list.arns) > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-elb-5xx-count"
  alarm_description   = "ALB HTTP 5XX 서버 오류 개수"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = data.aws_lb.alb[0].arn_suffix }
  statistic           = "Sum"
  period              = 180
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-elb-5xx-count" })
}

# =============================================================================
# SNS
# =============================================================================
resource "aws_sns_topic" "this" {
  name = "${var.name_prefix}-alerts"

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-sns-topic" })
}
