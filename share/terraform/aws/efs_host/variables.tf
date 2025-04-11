variable "network" {
  description = "Name of the remote state block to use for the network"
}

variable "efs" {
  description = "Name of the remote state block to use for the EFS"
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

