variable "role_name" {
  description = "Role name"
  type = string
}

variable "principal" {
  description = "Principal that can assume the role"
  type = map(any)
}

variable "action" {
  description = "Action of the role"
  default = "sts:AssumeRole"
}
