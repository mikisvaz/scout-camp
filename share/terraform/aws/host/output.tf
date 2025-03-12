output "aws_instance_id" {
  description = "Code that identifies the AWS instance"
  value = aws_instance.this.id
}

output "aws_instance_ip" {
  description = "Public IP address of the AWS instance"
  value = aws_instance.this.public_ip
}
