# =============================================================================
# Monitoring Outputs
# =============================================================================
output "sns_topic_arn" {
  description = "알람 알림 SNS Topic ARN"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "알람 알림 SNS Topic 이름"
  value       = aws_sns_topic.alerts.name
}

output "alarm_arns" {
  description = "생성된 CloudWatch Alarm ARN 목록"
  value = {
    ecs_cpu         = var.enable_ecs_alarms ? aws_cloudwatch_metric_alarm.ecs_cpu_high[0].arn : null
    ecs_memory      = var.enable_ecs_alarms ? aws_cloudwatch_metric_alarm.ecs_memory_high[0].arn : null
    rds_cpu         = aws_cloudwatch_metric_alarm.rds_cpu_high.arn
    rds_connections = aws_cloudwatch_metric_alarm.rds_connections_high.arn
    rds_storage     = aws_cloudwatch_metric_alarm.rds_storage_low.arn
    alb_5xx         = var.enable_alb_alarms ? aws_cloudwatch_metric_alarm.alb_5xx_errors[0].arn : null
    alb_response    = var.enable_alb_alarms ? aws_cloudwatch_metric_alarm.alb_response_time[0].arn : null
  }
}
