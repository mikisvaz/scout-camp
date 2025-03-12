output "available_aws_offerings" {
  value = data.aws_ec2_instance_type_offerings.available
}

output "default_ami" {
  value = data.aws_ami.ubuntu2004.id
}

output "my_zones" {
  value = keys({ for az, details in data.aws_ec2_instance_type_offerings.available :
                      az => details.instance_types if length(details.instance_types) != 0 })
}

output "ipam" {
  value = "aws"
}
