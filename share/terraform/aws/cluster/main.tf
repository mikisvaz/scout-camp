locals {
  cidr_block = "${var.cidr_block_base}/${var.cidr_block_mask}"
  cidr_block_dest = "0.0.0.0/0"

}

resource "aws_vpc" "this" {
    cidr_block = local.cidr_block

    tags = {
        Name = var.cidr_nametag
    }
}

resource "aws_subnet" "this" {
    vpc_id     = aws_vpc.this.id
    cidr_block = local.cidr_block

    map_public_ip_on_launch = var.map_public_ip_on_launch

    tags = {
        Name = var.subnet_nametag
    }

    availability_zone      = var.availability_zone
}


resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name = var.gateway_nametag
    }
}

resource "aws_route" "this" {
    route_table_id         = aws_vpc.this.main_route_table_id
    destination_cidr_block = local.cidr_block_dest
    gateway_id             = aws_internet_gateway.this.id
}

resource "aws_security_group" "this" {
  name        = "allow_all"
  description = "Allow all traffic"
  vpc_id     = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.cidr_block_dest]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.cidr_block_dest]
  }

  tags = {
    Name = var.security_group_nametag
  }
}

