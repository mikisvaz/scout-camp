variable "policy_name" {
  type    = string
}

variable "statement" {
  type    = list(object({
    Action   = any
    Effect   = string
    Resource = any
  }))
}

