locals {
  base = {
    service_name  = replace(var.service_name, ".", "-")
    service_image = "${var.deployment_config.image_registry}:${var.deployment_config.image}"
    service_networks = [
      for network in values(data.docker_network.service) : network.id
    ]
    service_resources_mib_cores = {
      reserve_cpu    = (tonumber(replace(var.container_config.resources.reservations.cpus, "m", "")) / 1000),
      reserve_memory = tonumber(replace(var.container_config.resources.reservations.memory, "Mi", "")),
      limit_cpu      = (tonumber(replace(var.container_config.resources.limits.cpus, "m", "")) / 1000),
      limit_memory   = tonumber(replace(var.container_config.resources.limits.memory, "Mi", "")),
    }
    service_resources_bytes_nanos = {
      reserve_cpu    = tonumber(replace(var.container_config.resources.reservations.cpus, "m", "")) * 1000000
      reserve_memory = tonumber(replace(var.container_config.resources.reservations.memory, "Mi", "")) * 1024 * 1024
      limit_cpu      = tonumber(replace(var.container_config.resources.limits.cpus, "m", "")) * 1000000
      limit_memory   = tonumber(replace(var.container_config.resources.limits.memory, "Mi", "")) * 1024 * 1024
    }
    service_read_only_fs = var.container_config.read_only_fs
    service_env          = var.env
    service_configs = [
      for key, value in docker_config.service : {
        source_id = value.id
        source    = value.name
        target    = "/run/configs/${key}"
        mode      = 0444
      }
    ]
    service_secrets = [
      for key, value in docker_secret.service : {
        source_id = value.id
        source    = value.name
        target    = "/run/secrets/${key}.env"
        mode      = 0444
      }
    ]
  }
  static = {
    service_bound_networks = [
      "apps",
    ]
  }
}
