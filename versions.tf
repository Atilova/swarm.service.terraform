terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "~> 0.15.0"
    }
  }
}
