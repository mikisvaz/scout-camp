# Get default VPC (optional if you want to restrict to default VPC)
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the region (filtered to default VPC if needed)
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
