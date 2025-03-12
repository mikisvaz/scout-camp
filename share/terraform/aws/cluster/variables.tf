variable "cidr_block_base" {
  description = "CIDR block base IP to use in the vpc (e.g. 10.0.0.0)"
  type = string
  default = "10.0.0.0"
}

variable "cidr_block_mask" {
  description = "CIDR block mask to use in the vpc (e.g. 16)"
  type = string
  default = "16"
}

variable "map_public_ip_on_launch" {
  description = "Map the publich ip on launch"
  type = bool
  default = true
}

variable "availability_zone" {
  description = "Availability zone for cluster"
  type = string
  default = null
}

# NAMETAGS

variable "cidr_nametag" {
  description = "Name tag to assign the aws CIDR"
  type = string
  default = "one-provision-aws_CIDR"
}

variable "subnet_nametag" {
  description = "Name tag to assign the aws subnet"
  type = string
  default = "one-provision-aws_subnet"
}

variable "gateway_nametag" {
  description = "Name tag to assign the aws gateway"
  type = string
  default = "one-provision-aws_gateway"
}

variable "security_group_nametag" {
  description = "Name tag to assign the aws security group"
  type = string
  default = "one-provision-aws_security_group"
}
