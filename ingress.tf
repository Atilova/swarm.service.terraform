module "traefik_ingress_external_http_labels" {
  source             = "./traefik.ingress.labels"
  enabled            = var.ingress.external.http.enabled
  service_name       = var.service_name
  container_port     = var.ingress.external.http.container_port
  hostname_prefix    = "apps"
  exposed_urls       = var.ingress.external.http.exposed_urls
  router_prefix      = "external"
  router_entrypoints = ["external", "external-tls"]
}

module "traefik_ingress_internal_http_labels" {
  source             = "./traefik.ingress.labels"
  enabled            = var.ingress.internal.http.enabled
  service_name       = var.service_name
  container_port     = var.ingress.internal.http.container_port
  hostname_prefix    = "internal-apps"
  exposed_urls       = var.ingress.internal.http.exposed_urls
  router_prefix      = "internal"
  router_entrypoints = ["internal", "internal-tls"]
}
