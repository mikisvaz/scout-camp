data "aws_availability_zones" "available" {}

data "aws_ec2_instance_type_offerings" "available" {

    for_each=toset(data.aws_availability_zones.available.names)

    filter {
        name   = "instance-type"
        values = ["c5.metal"]
    }

    filter {
        name   = "location"
        values = [each.key]
    }

    location_type = "availability-zone"
}

data "aws_ami" "ubuntu2004" {

    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}
