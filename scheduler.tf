# EventBridge Scheduler — daily ECS redeployment
#
# Calls ecs:UpdateService with forceNewDeployment=true on a schedule
# (default: 01:00 Asia/Kuala_Lumpur daily) so that n8n pulls the latest
# container image every day without requiring `terragrunt apply`.
#
# Coexists with the `triggers { redeployment = plantimestamp() }` blocks
# on the ECS services: Terraform-side triggers handle manual redeploys
# during `terragrunt apply`; this scheduler handles the automated daily one.

# IAM role assumed by EventBridge Scheduler to call ECS on our behalf
resource "aws_iam_role" "ecs_scheduler" {
  count = var.daily_redeployment_enabled ? 1 : 0

  name = "${var.prefix}-ecs-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ecs_scheduler" {
  count = var.daily_redeployment_enabled ? 1 : 0

  name = "${var.prefix}-ecs-scheduler-policy"
  role = aws_iam_role.ecs_scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        # Scoped to services inside this cluster
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.ecs.name}/*"
        ]
      },
      {
        # ecs:UpdateService requires iam:PassRole for the task/execution roles
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.taskrole.arn,
          aws_iam_role.executionrole.arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Schedule — n8n main service
resource "aws_scheduler_schedule" "n8n_main" {
  count = var.daily_redeployment_enabled ? 1 : 0

  name        = "${var.prefix}-daily-redeploy-main"
  description = "Daily force-new-deployment of the n8n main ECS service"
  group_name  = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.daily_redeployment_cron
  schedule_expression_timezone = var.daily_redeployment_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.ecs_scheduler[0].arn

    input = jsonencode({
      Cluster            = aws_ecs_cluster.ecs.name
      Service            = aws_ecs_service.service.name
      ForceNewDeployment = true
    })

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}

# Schedule — n8n worker service
resource "aws_scheduler_schedule" "n8n_worker" {
  count = var.daily_redeployment_enabled ? 1 : 0

  name        = "${var.prefix}-daily-redeploy-worker"
  description = "Daily force-new-deployment of the n8n worker ECS service"
  group_name  = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.daily_redeployment_cron
  schedule_expression_timezone = var.daily_redeployment_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.ecs_scheduler[0].arn

    input = jsonencode({
      Cluster            = aws_ecs_cluster.ecs.name
      Service            = aws_ecs_service.worker.name
      ForceNewDeployment = true
    })

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}

# Schedule — browserless service (only if browserless is enabled)
resource "aws_scheduler_schedule" "browserless" {
  count = var.daily_redeployment_enabled && var.browserless_enabled ? 1 : 0

  name        = "${var.prefix}-daily-redeploy-browserless"
  description = "Daily force-new-deployment of the browserless ECS service"
  group_name  = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.daily_redeployment_cron
  schedule_expression_timezone = var.daily_redeployment_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.ecs_scheduler[0].arn

    input = jsonencode({
      Cluster            = aws_ecs_cluster.ecs.name
      Service            = aws_ecs_service.browserless[0].name
      ForceNewDeployment = true
    })

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}
