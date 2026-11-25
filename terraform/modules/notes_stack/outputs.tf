output "app_url" {
  value = "http://localhost:${var.app_port}"
}

output "network_name" {
  value = docker_network.this.name
}

output "db_container" {
  value = docker_container.db.name
}
