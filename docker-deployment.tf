resource "docker_config" "service" {
  for_each = {
    for config in var.config_mounts : config.name => config.value
  }

  name = "tf-${local.service_name_safe}-${replace(each.key, ".", "-")}-${substr(sha256(each.value), 0, 16)}"
  data = base64encode(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_secret" "service" {
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

      dynamic "healthcheck" {
        for_each = var.healthcheck.enabled ? [1] : []

        content {
          test         = var.healthcheck.command
          interval     = var.healthcheck.interval
          timeout      = var.healthcheck.timeout
          retries      = var.healthcheck.retries
          start_period = var.healthcheck.start_period
        }
      }

      dynamic "configs" {
        for_each = docker_config.service

        content {
          config_id   = configs.value.id
          config_name = configs.value.name
          file_name   = "/run/configs/${configs.key}"
          file_mode   = 0444
        }
      }

      dynamic "secrets" {
        for_each = docker_secret.service

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

    dynamic "networks_advanced" {
      for_each = toset(local.service_networks)

      content {
        name = networks_advanced.value
      }
    }
  }

  mode {
    replicated {
      replicas = var.deployment_config.replicas
    }
  }

  endpoint_spec {
    mode = "vip"

    dynamic "ports" {
      for_each = toset(var.ingress.node)

      content {
        publish_mode   = "ingress"
        protocol       = ports.value.protocol
        target_port    = ports.value.container_port
        published_port = ports.value.node_port
      }
    }
  }

  update_config {
    parallelism = 1
    delay       = "5s"
    order       = "start-first"
  }

  dynamic "labels" {
    for_each = merge(
      module.traefik_ingress_external_http_labels.labels,
      module.traefik_ingress_internal_http_labels.labels,
    )

    content {
      label = labels.key
      value = labels.value
    }
  }
}

# TODO: Clean up old containers, as some remain stopped after a rollout.
# TODO: Switch application deployment to YAML-based stack deploys.
# Terraform will configure a local stack deploy file,
# and a local provisioner will apply/deploy from file and monitor rollout status.
# Deploying with Terraform's docker_service triggers a forced service recreation
# each time labels are changed. There is a workaround:
# firstly, update labels manually with the CLI, then run plan/apply
# with new code changes. However, this is inconvenient.
# Another downside is that it removes the ability to perform
# rolling updates one by one for different deployments.
# So, if I want to add a worker deployment later, both the API and worker config
# will be applied at the same time, which is bad for monitoring and rollback.
