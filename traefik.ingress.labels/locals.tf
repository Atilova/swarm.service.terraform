locals {
  service_name_hostname = replace(var.service_name, ".", "")
  router_entrypoints    = join(",", var.router_entrypoints)
  host_rule             = "HostRegexp(`^${local.service_name_hostname}-${var.hostname_prefix}\\.(.+)$`)"

  routers = {
    for from, to in var.exposed_urls :
    replace(replace(trim(from, "/"), "/", "-"), ".", "-") => {
      from                  = from
      to                    = to
      to_has_trailing_slash = endswith(to, "/")
      is_root               = from == "/"
      is_prefix             = endswith(from, "/")
      trimmed_from          = trimsuffix(from, "/")
      escaped_trimmed       = replace(trimsuffix(from, "/"), "/", "\\/")
      escaped_from          = replace(from, "/", "\\/")
      trimmed_to            = trimsuffix(to, "/")
      normalized_to         = (endswith(from, "/") ? "${trimsuffix(to, "/")}/" : to)
      priority              = 10 + length(split("/", trim(from, "/")))
    }
  }

  router_maps = [
    for router_name, r in local.routers : {
      "traefik.http.routers.${local.service_name_hostname}-${router_name}-${var.router_prefix}.rule" = (
        r.is_root ?
        "${local.host_rule} && PathPrefix(`/`)" :
        (
          r.is_prefix ?
          "${local.host_rule} && (Path(`${r.trimmed_from}`) || PathPrefix(`${r.from}`))" :
          "${local.host_rule} && (Path(`${r.from}`) || Path(`${r.from}/`))"
        )
      )

      "traefik.http.routers.${local.service_name_hostname}-${router_name}-${var.router_prefix}.entrypoints" = "${local.router_entrypoints}"
      "traefik.http.routers.${local.service_name_hostname}-${router_name}-${var.router_prefix}.service"     = "${local.service_name_hostname}-service"
      "traefik.http.routers.${local.service_name_hostname}-${router_name}-${var.router_prefix}.priority"    = tostring(r.priority)
    }
  ]

  middleware_maps = [
    for router_name, r in local.routers : (
      r.from != r.normalized_to ? {
        "traefik.http.routers.${local.service_name_hostname}-${router_name}-${var.router_prefix}.middlewares" = "${local.service_name_hostname}-${router_name}-${var.router_prefix}-rewrite"

        "traefik.http.middlewares.${local.service_name_hostname}-${router_name}-${var.router_prefix}-rewrite.replacepathregex.regex" = (
          r.is_prefix ?
          "^${r.escaped_trimmed}(\\/.*)?$" :
          (
            r.to_has_trailing_slash ?
            "^${r.escaped_from}/?$" :
            "^${r.escaped_from}(/?)$"
          )
        )

        "traefik.http.middlewares.${local.service_name_hostname}-${router_name}-${var.router_prefix}-rewrite.replacepathregex.replacement" = (
          r.is_prefix ?
          "${r.trimmed_to}$1" :
          (r.to_has_trailing_slash ? "${r.to}" : "${r.to}$1")
        )
      } : {}
    )
  ]

  router_labels  = length(local.router_maps) > 0 ? merge(local.router_maps...) : {}
  rewrite_labels = length(local.middleware_maps) > 0 ? merge(local.middleware_maps...) : {}

  base_labels = {
    "traefik.enable"                                                                        = "true"
    "traefik.swarm.lbswarm"                                                                 = "true"
    "traefik.http.services.${local.service_name_hostname}-service.loadbalancer.server.port" = tostring(var.container_port)
  }

  labels = (
    var.enabled ?
    merge(
      local.base_labels,
      local.router_labels,
      local.rewrite_labels
    ) :
    {}
  )
}
