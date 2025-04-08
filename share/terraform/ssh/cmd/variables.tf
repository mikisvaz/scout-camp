variable "host" {
  description = "Target host for SSH"
  type        = string
}

variable "user" {
  description = "Username for SSH"
  type        = string
}

variable "service_id" {
  description = "Identifier of the service, should be unique to avoid collisions"
  type        = string
}

variable "command" {
  description = "Command to execute"
  type        = string
}
