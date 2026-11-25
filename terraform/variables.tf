variable "docker_host" {
  description = "Docker endpoint. Linux/macOS/WSL: unix:///var/run/docker.sock. Windows: npipe:////.//pipe//docker_engine"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "notes-tf"
}

variable "app_image" {
  description = "Local image to run (build it first: docker compose build)"
  type        = string
  default     = "notes-app:1.0"
}

variable "app_port" {
  description = "Port on your PC where the app will be reachable"
  type        = number
  default     = 5001
}

variable "db_user" {
  type    = string
  default = "notes"
}

variable "db_name" {
  type    = string
  default = "notes"
}

variable "db_password" {
  description = "Database password (set in terraform.tfvars, never commit it)"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Flask SECRET_KEY"
  type        = string
  sensitive   = true
}
