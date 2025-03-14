variable "function_name" {
  description = "Lambda function name"
  type = string
}
variable "runtime" {
  description = "Ruby runtime"
  type = string
  default = "ruby3.2"
}
variable "filename" {
  description = "ZIP filename with lambda handler"
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
