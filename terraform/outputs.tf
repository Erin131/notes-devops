output "app_url" {
  description = "Open this in your browser"
  value       = module.notes_stack.app_url
}

output "network_name" {
  value = module.notes_stack.network_name
}

output "db_container" {
  value = module.notes_stack.db_container
}
