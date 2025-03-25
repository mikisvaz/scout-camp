output "arn" {
  description = "Role arn"
  value = aws_iam_role.this.arn
}

output "name" {
  description = "Role name"
  value = aws_iam_role.this.name
}

output "id" {
  description = "Role id"
  value = aws_iam_role.this.id
}

