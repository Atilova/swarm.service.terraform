variable "enabled" {
  type        = bool
  default     = true
  description = "Enable or disable generation of Traefik labels for the service"
}

variable "service_name" {
  type        = string
  description = "Full name of the service used for Traefik router and service labels"
}

variable "container_port" {
  type        = number
  description = "Internal container port that Traefik routes traffic to"
}

variable "hostname_prefix" {
  type        = string
  description = "Prefix added to service hostname"
  default     = "apps"
}

variable "router_prefix" {
  type        = string
  description = "Prefix added to all generated Traefik router names"
}

variable "router_entrypoints" {
  type        = list(string)
  description = "List of Traefik entrypoints used to expose the service"
}

variable "exposed_urls" {
  type        = map(string)
  default     = {}
  description = "Map of URL paths to expose, use empty to expose root"
}
