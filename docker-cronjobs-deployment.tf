locals {
  cronjobs_normalized = [
    for cronjob in var.cronjobs : merge(cronjob, {
      name = lower(replace(cronjob.name, ".", "-"))
    })
  ]
  cronjobs_deployment_stack_file = "/tmp/cronjobs_deployment_stack.yaml"
  cronjobs_deployment_stack_name = "tf-cj-${local.base.service_name}"
  cronjobs_deployment_commands = {
    for cronjob in local.cronjobs_normalized : cronjob.name => trimspace(<<-EOT
      #!/bin/sh
      set -euo pipefail

      ${cronjob.command}
    EOT
    )
  }
  cronjobs_deployment_config = merge(local.base, {
    cronjobs = [
      for cronjob in local.cronjobs_normalized : {
        name     = cronjob.name
        schedule = cronjob.schedule
        command_config = {
          source_id = docker_config.cronjobs_deployment_commands[cronjob.name].id
          source    = docker_config.cronjobs_deployment_commands[cronjob.name].name
          mode      = 0444
        }
      }
    ]
  })
}

resource "docker_config" "cronjobs_deployment_commands" {
  for_each = local.cronjobs_deployment_commands

  name = "tf-cj-${local.base.service_name}-${each.key}-${substr(sha256(each.value), 0, 16)}-sh"
  data = base64encode(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

resource "local_file" "cronjobs_deployment_stack" {
  filename = local.cronjobs_deployment_stack_file
  content = templatefile(
    "${path.module}/templates/cronjobs_deployment_stack.yaml.tpl",
    local.cronjobs_deployment_config
  )
}

resource "null_resource" "apply_cronjobs_stack" {
  provisioner "local-exec" {
    quiet       = true
    interpreter = ["/usr/bin/env", "bash", "-c"]

    command = <<-EOT
      #!/bin/bash
      set -euo pipefail

      timeout 300s docker stack deploy \
        -c ${local.cronjobs_deployment_stack_file} \
        --detach \
        --prune \
        ${local.cronjobs_deployment_stack_name}
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    quiet       = true
    interpreter = ["/usr/bin/env", "bash", "-c"]

    # Destroy stack before updating, resolves: https://github.com/moby/moby/issues/39891
    command = <<-EOT
      #!/bin/bash
      set -euo pipefail

      docker stack rm ${self.triggers.stack_name} || true
    EOT
  }

  triggers = {
    stack_name = local.cronjobs_deployment_stack_name
    stack_sha  = sha256(local_file.cronjobs_deployment_stack.content)
  }

  depends_on = [
    docker_config.service,
    docker_secret.service,
    docker_config.cronjobs_deployment_commands,
    null_resource.pre_deployment_jobs
  ]
}
