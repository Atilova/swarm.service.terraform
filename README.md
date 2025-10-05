# Swarm Service Terraform
Module for deploying Docker-based applications to a Swarm cluster using Terraform.


## TODO: Features


## Pre-requisites
1. [Bash >= 4](https://www.gnu.org/software/bash/)
2. [json2env](https://github.com/m-lamonaca/json-to-env)
    ```sh
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/m-lamonaca/json-to-env/releases/download/0.3.1/json2env-installer.sh | sh
    ```
3. [Bitwarden CLI](http://github.com/bitwarden/cli)
    (Depends whether you use [embedded_client](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs#client-implementation) in provider configuration or not)


## Required Terraform Providers
| Provider                                                                                    | Version     |
|---------------------------------------------------------------------------------------------|-------------|
| [hashicorp/null](https://registry.terraform.io/providers/hashicorp/null/latest)             | `~> 3.2`    |
| [hashicorp/external](https://registry.terraform.io/providers/hashicorp/external/latest)     | `~> 2.3`    |
| [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest)     | `~> 3.6`    |
| [maxlaverse/bitwarden](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest) | `~> 0.15.0` |


## Example Usage
```terraform-hcl
module "service" {
  source = "git@github.com:Atilova/swarm.service.terraform.git?ref=master"

  service_name = "draft.python.api"
  deployment_config = {
    replicas       = 2
    image          = "3.12-alpine"
    image_registry = "python"
  }
  container_config = {
    read_only_fs = true
    resources = {
      reservations = {
        cpus   = "100m"
        memory = "128Mi"
      }
      limits = {
        cpus   = "200m"
        memory = "256Mi"
      }
    }
  }
  ingress = {
    external = {
      http = {
        container_port = 8000
        exposed_urls = {
          "/api/v1/" = "/api/v1/"
          "/metrics" = "/metrics"
        }
      }
    }
    internal = {
      http = {
        container_port = 8000
        exposed_urls = {
          "/" = "/"
        }
      }
    }
  }
  healthcheck = {
    enabled = true
  }
  pre_deployment_jobs = [
    {
      command = "python -V; env | grep cf__test__config"
    },
    {
      command = "cat /run/secrets/app.env; cat /run/secrets/database.env"
    },
    {
      command = "cat /run/configs/well-known.jwks.json"
    }
  ]
  env = {
    "cf__test__config" = "false"
  }
  config_mounts = [
    {
      name  = "well-known.jwks.json"
      value = file("${path.module}/well-known.jwks.json")
    }
  ]
  bitwarden_secret_mounts = {
    "app" = {
      id = "uuid-1"
    }
    "database" = {
      id = "uuid-2"
    }
  }
}
```


## Ingress Configuration
It allows configuring HTTP ingress for your service using Traefik.
You can define **external** and **internal** endpoints, map exposed URLs to container paths, and control block vs direct forwarding.

### Forwarding examples
| From URL (Exposed)  | To URL (Container) | Example Request    | Container Received    |
|---------------------|--------------------|--------------------|-----------------------|
| /api/v2/            | /api/v2/           | /api/v1/config/    | /api/v1/config/       |
| /api/v1/            | /api/              | /api/v1/config/    | /api/config/          |
| /api/v1/            | /api               | /api/v1/config/    | /api/config/          |
| /metrics            | /metrics           | /metrics           | /metrics              |
| /metrics            | /metrics           | /metrics/          | /metrics/             |
| /rule               | /endpoint/         | /rule              | /endpoint/            |
| /rule               | /endpoint/         | /rule/             | /endpoint/            |
| /                   | /                  | /anything          | /anything             |

> **Block mode**: when the `from` URL ends with `/`
prefix forwarding (e.g., `/api/v1/*` → `/api/*`).
---
> **Direct mode**: when the `from` URL does not end with `/` →
exact match forwarding (e.g., `/metrics` → `/metrics`, `/rule` → `/endpoint/`).

Trailing slash of the `to` path is respected in **direct mode only**;
in block mode, the remainder of the request path is appended automatically.
