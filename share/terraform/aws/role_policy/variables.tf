variable "policy_name" {
  type    = string
}

variable "statement" {
  type    = list(object({
    Action   = any
    Effect   = string
    Resource = string
  }))
}

variable "role" {
  description = "Role id to which to attach policy"
  type = string
}
