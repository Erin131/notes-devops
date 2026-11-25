terraform {
  required_providers {
    docker = {
      source  = "kreuzwerk/docker"
      version = "~> 3.0"
    }
  }
}

# Private network for the two containers
resource "docker_network" "this" {
  name = "${var.project_name}-net"
}

# Disk that keeps the database data
resource "docker_volume" "pgdata" {
  name = "${var.project_name}-pgdata"
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name  = "${var.project_name}-db"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=${var.db_name}",
  ]

  networks_advanced {
    name    = docker_network.this.name
    aliases = ["db"]
  }

  volumes {
    volume_name    = docker_volume.pgdata.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "docker_container" "app" {
  name  = "${var.project_name}-app"
  image = var.app_image

  env = [
    "POSTGRES_HOST=db",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=${var.db_name}",
    "SECRET_KEY=${var.secret_key}",
    "APP_COLOR=terraform",
  ]

  ports {
    internal = 5000
    external = var.app_port
  }

  networks_advanced {
    name = docker_network.this.name
  }

  restart    = "unless-stopped"
  depends_on = [docker_container.db]
}
