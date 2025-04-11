data "aws_vpc" "default" {
  filter {
    name   = "is-default"
    values = ["true"]
  }
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

