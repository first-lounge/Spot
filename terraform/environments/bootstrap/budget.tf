variable "alert_email" {
  description = "알람용 이메일"
  type        = string
}

locals {
  thresholds = range(30, 100, 30)
}

# resource "aws_budgets_budget" "spot" {
#   name              = "spot-budget-custom"
#   budget_type       = "COST"
#   limit_amount      = "345"
#   limit_unit        = "USD"
#   time_unit         = "CUSTOM"

#   time_period_start = "2026-01-05_00:00"
#   time_period_end   = "2026-02-16_23:59"

#   dynamic "notification" {
#     for_each = local.thresholds

#     content {
#       comparison_operator        = "GREATER_THAN"
#       threshold                  = notification.value
#       threshold_type             = "PERCENTAGE"
#       notification_type          = "ACTUAL"
#       subscriber_email_addresses = [var.alert_email]
#     }
#   }
# }

# 알림 테스트용
resource "aws_budgets_budget" "monthly" {
  name         = "monthly-cost-budget"
  budget_type  = "COST"
  limit_amount = "1" # 테스트용 1달러
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false # 크레딧 차감 전 금액으로 계산
  }

  dynamic "notification" {
    for_each = local.thresholds

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
