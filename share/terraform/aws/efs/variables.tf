variable "remote" {
  description = "Name of the remote state block to use"
}

variable "sg_keys" {
  description = "List of output names in the remote state representing security group IDs"
  type        = list(string)
  default     = ["aws_network_efs_sg_id"]
}
