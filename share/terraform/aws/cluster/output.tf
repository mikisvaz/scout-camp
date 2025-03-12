output "aws_subnet_id" {
  description = "Submet id"
  value = aws_subnet.this.id
}

output "aws_security_group_id" {
  description = "Security group id"
  value = aws_security_group.this.id
}
