locals {
  service_name = replace(var.service_name, ".", "-")
}

resource "docker_config" "service" {
  for_each = merge({
    for config in var.config_mounts : config.name => config.value
  })

  name = "tf-${local.service_name}-${replace(each.key, ".", "-")}-${substr(sha256(each.value), 0, 16)}"
  data = base64encode(each.value)

  lifecycle {
    create_before_destroy = true
  }
}

resource "docker_secret" "service" {
  for_each = merge({
    for name, value in data.external.bitwarden_service_secrets_env :
    name => value.result.env
  })

  name = "tf-${local.service_name}-${replace(each.key, ".", "-")}-${substr(sha256(each.value), 0, 16)}"
  data = base64encode(each.value)

  lifecycle {
    create_before_destroy = true
  }
}
