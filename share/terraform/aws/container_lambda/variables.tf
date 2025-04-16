variable "function_name" {
  description = "Lambda function name"
  type = string
}
variable "timeout" {
  description = "Timeout for call"
  type = number
  default = 30
}
variable "environment_variables" {
  type        = map(string)
  description = "A map of environment variables to pass to the resource"
  default     = {}
}
variable "role_arn" {
}
variable "image" {
}
variable "memory" {
  type        = number
  description = "The memory (MiB) for the task"
  default     = 512
}

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

