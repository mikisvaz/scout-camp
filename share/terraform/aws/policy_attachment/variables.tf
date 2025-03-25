variable "policy_arn" {
  description = "Policy arn"
  type = string
}
variable "policy_name" {
  description = "Policy name"
  type = string
}
variable "roles" {
  description = "Roles to which to attach policy"
  type = set(string)
}
