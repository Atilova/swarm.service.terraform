locals {
  pre_deployment_config = {
    jobs = [
      for job in var.pre_deployment_jobs : {
        timeout     = job.timeout
        command_b64 = base64encode(job.command)
      }
    ]
    service_name     = local.service_name_safe
    service_image    = local.service_image
    service_networks = []
    service_resources = {
      reserve_cpu    = local.resources.reservation_cpu_cores,
      reserve_memory = local.resources.reservation_memory_mib,
      limit_cpu      = local.resources.limit_cpu_cores,
      limit_memory   = local.resources.limit_memory_mib,
    }
    service_read_only_fs = var.container_config.read_only_fs
    service_env          = var.env
    service_configs = [
      for key, value in docker_config.service_configs : {
        source = value.name
        target = "/run/configs/${key}"
        mode   = 0444
      }
    ]
    service_secrets = [
      for key, value in docker_secret.service_secrets : {
        source = value.name
        target = "/run/secrets/${key}.env"
        mode   = 0444
      }
    ]
    service_wake_up_backoff = {
      timeout_seconds = -1
      step            = 1
      max_delay       = 10
    }
  }
}

resource "null_resource" "pre_deployment_jobs" {
  provisioner "local-exec" {
    quiet       = true
    interpreter = ["/bin/bash", "-c"]

    command = templatefile(
      "${path.module}/templates/pre_deployment_job.sh.tpl",
      local.pre_deployment_config
    )
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    docker_secret.service_secrets,
    docker_config.service_configs
  ]
}
