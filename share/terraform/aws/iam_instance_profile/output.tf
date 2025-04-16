output "arn" {
  description = "Instance profile arn"
  value = aws_iam_instance_profile.this.arn
}

output "profile_name" {
  description = "Instance profile name"
  value = aws_iam_instance_profile.this.name
}

output "id" {
  description = "Instance profile id"
  value = aws_iam_instance_profile.this.id
}

