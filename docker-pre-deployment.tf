locals {
  pre_deployment_config = merge(local.base, {
    jobs = [
      for job in var.pre_deployment_jobs : {
        timeout     = job.timeout
        command_b64 = base64encode(job.command)
      }
    ]
    service_wake_up_backoff = {
      timeout_seconds = -1
      step            = 1
      max_delay       = 10
    }
  })
}

resource "null_resource" "pre_deployment_jobs" {
  provisioner "local-exec" {
    quiet       = true
    interpreter = ["/usr/bin/env", "bash", "-c"]

    command = templatefile(
      "${path.module}/templates/pre_deployment_jobs.sh.tpl",
      local.pre_deployment_config
    )
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    docker_config.service,
    docker_secret.service
  ]
}
