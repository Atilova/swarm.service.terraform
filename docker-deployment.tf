# resource "docker_network" "service_net" {
#   name   = "tf-${local.service_name_safe}-net"
#   driver = "overlay"
# }

resource "docker_config" "service_configs" {
  for_each = {
    for config in var.config_mounts : config.name => config.value
  }

  name = "tf-${local.service_name_safe}-${replace(each.key, ".", "-")}-${substr(sha256(each.value), 0, 16)}"
  data = base64encode(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_secret" "service_secrets" {
  for_each = local.mounts.secrets

  name = "tf-${local.service_name_safe}-${replace(each.key, ".", "-")}-${substr(sha256(each.value), 0, 16)}"
  data = base64encode(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_service" "service" {
  name = local.service_name_safe
  depends_on = [
    null_resource.pre_deployment_jobs
  ]

  task_spec {
    container_spec {
      image     = local.service_image
      read_only = var.container_config.read_only_fs

      dynamic "configs" {
        for_each = docker_config.service_configs

        content {
          config_id   = configs.value.id
          config_name = configs.value.name
          file_name   = "/run/configs/${configs.key}"
          file_mode   = 0444
        }
      }

      dynamic "secrets" {
        for_each = docker_secret.service_secrets

        content {
          secret_id   = secrets.value.id
          secret_name = secrets.value.name
          file_name   = "/run/secrets/${secrets.key}.env"
          file_mode   = 0444
        }
      }

      env = var.env
    }

    resources {
      reservation {
        nano_cpus    = local.resources.reservation_nano_cpus
        memory_bytes = local.resources.reservation_memory_bytes
      }
      limits {
        nano_cpus    = local.resources.limit_nano_cpus
        memory_bytes = local.resources.limit_memory_bytes
      }
    }

    # networks_advanced {
    #   name = docker_network.service_net.id
    # }
  }

  mode {
    replicated {
      replicas = var.deployment_config.replicas
    }
  }

  endpoint_spec {
    ports {
      target_port    = 80
      published_port = 8080
      publish_mode   = "ingress"
    }
  }

  update_config {
    parallelism = 1
    delay       = "5s"
    order       = "start-first"
  }
}

# TODO: Clean up old containers, since some remain stopped after a rollout
