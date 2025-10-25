output "attached_networks" {
  value = local.base.service_networks
}

output "cronjobs_config" {
  value = local.cronjobs_deployment_config
}
