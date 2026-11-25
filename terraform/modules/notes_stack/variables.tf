variable "project_name" { type = string }
variable "app_image"    { type = string }
variable "app_port"     { type = number }
variable "db_user"      { type = string }
variable "db_name"      { type = string }

variable "db_password" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}
