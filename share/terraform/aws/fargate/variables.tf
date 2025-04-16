variable "network" {
  description = "Name of the remote state block to use for the network"
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

variable "task_family" {
  type        = string
  description = "The family name of the ECS task definition"
}

variable "cpu" {
  type        = number
  description = "The CPU units for the task"
  default     = 256
}

variable "memory" {
  type        = number
  description = "The memory (MiB) for the task"
  default     = 512
}

variable "container_name" {
  type        = string
  description = "Name of the container"
  default     = "app"
}

variable "image" {
  type        = string
  description = "Docker image URL for the container"
}

variable "user" {
  description = "User to use"
  type        = string
  default = null
}

variable "port_mappings" {
  type = list(object({
    containerPort = number
    hostPort      = number
    protocol      = string
  }))
  description = "List of port mappings for the container"
  default     = []
}

variable "command" {
  type        = list(string)
  description = "Command to run"
}

variable "entry_point" {
  type        = list(string)
  description = "Container entry point"
  default     = ["bash"]
}

variable "environment" {
  type        = map(string)
  description = "A map of environment variables to pass to the resource"
  default     = null
}
