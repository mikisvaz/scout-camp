resource "aws_iam_role_policy" "this" {
  name = var.policy_name
  role = var.role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.statement
  })
}
