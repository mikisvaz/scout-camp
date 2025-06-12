variable "network" {
  description = "Name of the remote state block to use for the network"
}
variable "instance_type" {
  description = "Instance to use"
  type = string
  default = "t2.micro"
}
variable "efs" {
  description = "Name of the remote state block to use for the EFS"
}

variable "policies" {
  description = "Name of the remote state block to use for the policies"
}

variable "sg_keys" {
  description = "List of output names in the remote state representing security group IDs"
  type        = list(string)
  default     = ["aws_network_efs_sg_id", "aws_network_ssh_sg_id"]
}
variable "mount_point" {
  description = "Where to mount the efs drive"
  type = string
  default = "/mnt/efs"
}

#variable "iam_instance_profile" {
#  description = "Instance profile"
#  type = string
#  default = null
#}
