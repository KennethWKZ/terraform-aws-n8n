# Optional ECS Exec session logging: the output of every `aws ecs execute-command` session goes to a CloudWatch log
# group encrypted with a KMS key. Off by default.
#
# Notes:
# - ECS uploads a session's output only if the container image has the `script` and `cat` utilities.
# - The log holds whatever was printed in the session (environment variables included), so limit who can read it.

locals {
  ecs_exec_log_group_name  = "${var.prefix}-ecs-exec-sessions"
  ecs_exec_log_kms_key_arn = var.ecs_exec_log_kms_key_arn != null ? var.ecs_exec_log_kms_key_arn : try(aws_kms_key.ecs_exec_logs[0].arn, null)
}

data "aws_iam_policy_document" "ecs_exec_logs_kms" {
  count = var.ecs_exec_logging_enabled && var.ecs_exec_log_kms_key_arn == null ? 1 : 0

  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "CloudWatchLogsUseForThisLogGroup"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.id}.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${local.ecs_exec_log_group_name}"]
    }
  }
}

resource "aws_kms_key" "ecs_exec_logs" {
  count                   = var.ecs_exec_logging_enabled && var.ecs_exec_log_kms_key_arn == null ? 1 : 0
  description             = "${var.prefix}: encrypts the ECS Exec session log group"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.ecs_exec_logs_kms[0].json

  tags = var.tags
}

resource "aws_kms_alias" "ecs_exec_logs" {
  count         = var.ecs_exec_logging_enabled && var.ecs_exec_log_kms_key_arn == null ? 1 : 0
  name          = "alias/${var.prefix}-ecs-exec-sessions"
  target_key_id = aws_kms_key.ecs_exec_logs[0].key_id
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  count             = var.ecs_exec_logging_enabled ? 1 : 0
  name              = local.ecs_exec_log_group_name
  retention_in_days = var.ecs_exec_log_retention_days
  kms_key_id        = local.ecs_exec_log_kms_key_arn

  tags = var.tags
}
