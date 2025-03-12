resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type

  private_ip    = var.private_ip
  subnet_id     = var.subnet_id

  vpc_security_group_ids = var.vpc_security_group_ids

  user_data     = local.user_data

  availability_zone      = var.availability_zone

  root_block_device {
      volume_size = var.volume_size
  }

  tags = {
    Name = var.host_nametag
  }
}

