resource "aws_iam_policy" "this" {
  name = var.policy_name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = var.statement
  })
}

