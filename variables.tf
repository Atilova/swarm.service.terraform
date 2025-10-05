variable "service_name" {
  type        = string
  description = "The name of the service to be deployed"

  validation {
    condition     = length(var.service_name) <= 24
    error_message = "Service name must be 24 characters or fewer"
  }
}

variable "deployment_config" {
  type = object({
    replicas       = number
    image          = string
    image_registry = optional(string, "docker.io/library/")
  })
  description = "Deployment settings: replicas, image, optional registry"
}

variable "container_config" {
  type = object({
    read_only_fs = optional(bool, false)
    resources = object({
      reservations = object({
        cpus   = string
        memory = string
      })
      limits = object({
        cpus   = string
        memory = string
      })
    })
  })
  description = "Container settings: read-only FS and resources"

  validation {
    condition = (
      can(regex("^[0-9]+m$", var.container_config.resources.reservations.cpus)) &&
      can(regex("^[0-9]+Mi$", var.container_config.resources.reservations.memory)) &&
      can(regex("^[0-9]+m$", var.container_config.resources.limits.cpus)) &&
      can(regex("^[0-9]+Mi$", var.container_config.resources.limits.memory))
    )
    error_message = "CPU must end with 'm' (e.g., 100m) and memory must end with 'M' (e.g., 128M) for both reservations and limits."
  }
}

variable "ingress" {
  type = object({
    node = optional(
      list(object({
        protocol       = optional(string, "tcp")
        container_port = number
        node_port      = number
      })),
      []
    )
    external = optional(
      object({
        http = object({
          enabled        = optional(bool, true)
          container_port = optional(number, 8000)
          exposed_urls = optional(map(string), {
            "/api/v1/" = "/api/v1/"
          })
        })
      }),
      {
        http = {
          enabled        = true
          container_port = 8000
          exposed_urls = {
            "/api/v1/" = "/api/v1/"
          }
        }
      }
    )
    internal = optional(
      object({
        http = object({
          enabled        = optional(bool, true)
          container_port = optional(number, 8000)
          exposed_urls = optional(map(string), {
            "/" = "/"
          })
        })
      }),
      {
        http = {
          enabled        = true
          container_port = 8000
          exposed_urls = {
            "/" = "/"
          }
        }
      }
    )
  })
  description = "Configuration for service ingress, including optional node ports and HTTP endpoints"
}

variable "pre_deployment_jobs" {
  type = list(object({
    command = string
    timeout = optional(number, 30)
  }))
  default     = []
  description = "List of jobs to execute before the service is deployed"
}

# TODO: is not avaible now, it is not clear how to run cronjobs in swarm
variable "cron_jobs" {
  type = map(object({
    command  = string
    schedule = string
  }))
  default     = {}
  description = "Map of scheduled jobs that run periodically within the service"
}

variable "env" {
  type        = map(string)
  default     = {}
  description = "Environment variables to set in the service container"
}

variable "config_mounts" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = "List of configuration values or files to mount into the container"

  validation {
    condition = alltrue([
      for config in var.config_mounts :
      length(config.name) <= 20 && can(regex("^[a-zA-Z0-9._-]+$", config.name))
    ])
    error_message = "Name must be 20 characters or fewer and match [a-zA-Z0-9._-]"
  }
}

variable "bitwarden_secret_mounts" {
  type = map(object({
    id = string
  }))
  default     = {}
  description = "Map of secrets retrieved from Bitwarden to mount in the container"

  validation {
    condition = alltrue([
      for key in keys(var.bitwarden_secret_mounts) :
      length(key) <= 20 && can(regex("^[a-zA-Z0-9._-]+$", key))
    ])
    error_message = "Each key must be 20 characters or fewer and match [a-zA-Z0-9._-]"
  }
}
