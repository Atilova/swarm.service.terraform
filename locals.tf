locals {
  service_name_safe = replace(var.service_name, ".", "-")
  service_image     = "${var.deployment_config.image_registry}${var.deployment_config.image}"

  mounts = {
    secrets = {
      for secret_name, value in data.external.bitwarden_service_secrets_env :
      secret_name => value.result.env
    }
  }

  resources = {
    reservation_nano_cpus    = tonumber(replace(var.container_config.resources.reservations.cpus, "m", "")) * 1000000
    reservation_cpu_cores    = (tonumber(replace(var.container_config.resources.reservations.cpus, "m", "")) / 1000)
    reservation_memory_bytes = tonumber(replace(var.container_config.resources.reservations.memory, "Mi", "")) * 1024 * 1024
    reservation_memory_mib   = tonumber(replace(var.container_config.resources.reservations.memory, "Mi", ""))
    limit_nano_cpus          = tonumber(replace(var.container_config.resources.limits.cpus, "m", "")) * 1000000
    limit_cpu_cores          = (tonumber(replace(var.container_config.resources.limits.cpus, "m", "")) / 1000)
    limit_memory_bytes       = tonumber(replace(var.container_config.resources.limits.memory, "Mi", "")) * 1024 * 1024
    limit_memory_mib         = tonumber(replace(var.container_config.resources.limits.memory, "Mi", ""))
  }
}
