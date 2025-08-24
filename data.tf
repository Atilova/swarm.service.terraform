data "bitwarden_secret" "service_secrets" {
  for_each = var.bitwarden_secret_mounts

  id = each.value.id
}

data "external" "bitwarden_service_secrets_env" {
  for_each = data.bitwarden_secret.service_secrets

  program = ["bash", "${path.module}/scripts/json2env.sh"]
  query = {
    prefix = "cf__"
    json   = each.value.value
  }
}
