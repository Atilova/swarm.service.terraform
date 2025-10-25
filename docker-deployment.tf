resource "docker_service" "service" {
  name = local.base.service_name
  depends_on = [
    docker_config.service,
    docker_secret.service,
    null_resource.pre_deployment_jobs
  ]

  task_spec {
    container_spec {
      image     = local.base.service_image
      read_only = local.base.service_read_only_fs

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
        for_each = {
          for config in local.base.service_configs : config.source_id => config
        }

        content {
          config_id   = configs.value.source_id
          config_name = configs.value.source
          file_name   = configs.value.target
          file_mode   = configs.value.mode
        }
      }

      dynamic "secrets" {
        for_each = {
          for secret in local.base.service_secrets : secret.source_id => secret
        }

        content {
          secret_id   = secrets.value.secret_id
          secret_name = secrets.value.source
          file_name   = secrets.value.target
          file_mode   = secrets.value.mode
        }
      }

      env = local.base.service_env
    }

    resources {
      reservation {
        nano_cpus    = local.base.service_resources_bytes_nanos.reserve_cpu
        memory_bytes = local.base.service_resources_bytes_nanos.reserve_memory
      }
      limits {
        nano_cpus    = local.base.service_resources_bytes_nanos.limit_cpu
        memory_bytes = local.base.service_resources_bytes_nanos.limit_memory
      }
    }

    dynamic "networks_advanced" {
      for_each = toset(local.base.service_networks)

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
