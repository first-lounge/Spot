# =============================================================================
# Discord 웹훅 
# =============================================================================
resource "aws_ssm_parameter" "discord_webhook" {
  description      = "Discord WebHook"
  name             = "/${var.project}/${var.environment}/alarm/discord_webhook"
  type             = "SecureString"
  value_wo         = "CHANGE"
  value_wo_version = 0

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-discord-webhook" })
}

# =============================================================================
# Lambda 
# =============================================================================
data "archive_file" "discord_notifier" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

locals {
  function_name = "${var.name_prefix}-discord-notifier"
}

resource "aws_lambda_function" "discord_notifier" {
  filename         = data.archive_file.discord_notifier.output_path
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  source_code_hash = data.archive_file.discord_notifier.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      WEBHOOK_PARAM_NAME = aws_ssm_parameter.discord_webhook.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.discord_notifier,
    aws_iam_role_policy_attachment.aws_lambda_basic_execution_role,
    aws_iam_role_policy_attachment.get_ssm_parameter
  ]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-discord-notifier-function" })
}

resource "aws_cloudwatch_log_group" "discord_notifier" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 1

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-discord-notifier-log-group" })
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.this.arn
}

resource "aws_sns_topic_subscription" "discord_notifier" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notifier.arn
}

resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-lambda-role" })
}

# Discord로의 전송 실패 이유를 CloudWatch에 기록할 때 필요
resource "aws_iam_role_policy_attachment" "aws_lambda_basic_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

# SSM 읽기 정책
resource "aws_iam_policy" "get_ssm_parameter" {
  name        = "${var.name_prefix}-get-ssm-parameter-policy"
  description = "Lambda Policy To Get SSM Parameter"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "GetParameterStore"
      Effect   = "Allow"
      Action   = "ssm:GetParameter",
      Resource = aws_ssm_parameter.discord_webhook.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "get_ssm_parameter" {
  policy_arn = aws_iam_policy.get_ssm_parameter.arn
  role       = aws_iam_role.lambda.name
}
