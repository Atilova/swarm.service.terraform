output "attached_networks" {
  value = local.service_networks
}

output "traefik_ingress_external_http_labels" {
  value = module.traefik_ingress_external_http_labels.labels
}

output "traefik_ingress_internal_http_labels" {
  value = module.traefik_ingress_internal_http_labels.labels
}
