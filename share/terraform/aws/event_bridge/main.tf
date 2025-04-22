# IAM Role for EventBridge to trigger ECS task
resource "aws_iam_role" "eventbridge_invoke_ecs" {
  name = "eventbridge_invoke_ecs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Permissions for EventBridge to run the task
resource "aws_iam_role_policy" "ecs_task_invoke_policy" {
  role = aws_iam_role.eventbridge_invoke_ecs.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:RunTask"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

# EventBridge rule triggered on S3 put event
resource "aws_cloudwatch_event_rule" "s3_put_event" {
  name        = "s3-put-to-uploads"
  description = "Triggers Fargate task on S3 file upload"
  event_pattern = jsonencode({
    source = ["aws.s3"],
    "detail-type" = ["Object Created"],
    detail = {
      bucket = {
        name = [var.bucket]
      },
      object = {
        key = [{
          prefix = var.directory
        }]
      }
    }
  })
}

# Target: ECS Fargate task
resource "aws_cloudwatch_event_target" "run_fargate" {
  rule      = aws_cloudwatch_event_rule.s3_put_event.name
  arn       = var.cluster_arn # Replace with your ECS Cluster ARN
  role_arn  = aws_iam_role.eventbridge_invoke_ecs.arn

  ecs_target {
    task_definition_arn = var.task_arn
    launch_type         = "FARGATE"
    network_configuration {
      assign_public_ip = true
      subnets          = data.aws_subnets.default.ids
    }
  }
}

# Allow S3 to send events to EventBridge
#resource "aws_s3_bucket_notification" "s3_event" {
#  bucket = var.bucket_name
#
#  eventbridge = true
#}
