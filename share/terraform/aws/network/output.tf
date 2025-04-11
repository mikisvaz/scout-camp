output "efs_sg_id" {
  value = aws_security_group.efs.id
}

output "ssh_sg_id" {
  value = aws_security_group.ssh.id
}
