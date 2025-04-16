resource "aws_iam_instance_profile" "this" {
  name = var.profile_name
  role = var.role
}

