variable "ami" {
  description = "AMI id for host"
  type = string
}

variable "instance_type" {
  description = "Type of AWS instance"
  type = string
  default = "t2.micro"
}

variable "volume_size" {
  description = "Size of volumes"
  type = number
  default = 512
}

variable "private_ip" {
  description = "Host private IP"
  type = string
  default = null
}

variable "user_data" {
  description = "User data for host"
  type = string
  default = null
}

variable "ssh_key" {
  description = "SSH key"
  type = string
  default = null
}

variable "ssh_keys" {
  description = "List of SSH key"
  type = list(string)
  default = null
}

variable "availability_zone" {
  description = "Availability zone for host"
  type = string
  default = null
}


variable "subnet_id" {
  description = "Cluster subnet id"
  type = string
  default = null
}

variable "vpc_security_group_ids" {
  description = "List of security group ids"
  type = list(string)
  default = null
}

variable "host_nametag" {
  description = "Name tag to assign the AWS instance"
  type = string
  default = "one-provision-aws_instance"
}

