output "arn" {
  description = "Policy arn"
  value = aws_iam_policy.this.arn
}

output "name" {
  description = "Policy name"
  value = aws_iam_policy.this.name
}

output "id" {
  description = "Policy id"
  value = aws_iam_policy.this.id
}

