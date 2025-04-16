resource "aws_key_pair" "this" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub") # Adjust if your key is elsewhere
}

resource "aws_instance" "this" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  iam_instance_profile = var.policies.outputs.ec2_host_profile_id

  key_name      = aws_key_pair.this.key_name

  tags = {
    Name = "EFS-Service"
  }

  # Open port 22 for SSH
  vpc_security_group_ids = local.security_group_ids

  user_data = <<-EOF
              #cloud-config
              package_update: true
              package_upgrade: true
              packages:
                - amazon-efs-utils
              runcmd:
                - mkdir -p ${var.mount_point}
                - mount -t efs -o tls ${local.efs_id}:/ ${var.mount_point}
                - echo "${local.efs_id}:/ ${var.mount_point} efs defaults,_netdev 0 0" >> /etc/fstab
EOF
}

