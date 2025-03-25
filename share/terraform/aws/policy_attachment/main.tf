resource "aws_iam_policy_attachment" "this" {
  name       = var.policy_name
  roles      = var.roles
  policy_arn = var.policy_arn
}
