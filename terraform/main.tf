# Root module: calls the reusable "notes_stack" module.
module "notes_stack" {
  source = "./modules/notes_stack"

  project_name = var.project_name
  app_image    = var.app_image
  app_port     = var.app_port
  db_user      = var.db_user
  db_name      = var.db_name
  db_password  = var.db_password
  secret_key   = var.secret_key
}
