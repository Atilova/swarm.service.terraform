## TODO


## Requirements
### json2env Util
```sh
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/m-lamonaca/json-to-env/releases/download/0.3.1/json2env-installer.sh | sh
```

### Bitwarden CLI
```sh
sudo snap install bw
```


## Example Usage
```hcl
module "service" {
  source = "git@github.com:Atilova/swarm.service.terraform.git?ref=master"

  service_name = "some.bot.api"
  deployment_config = {
    replicas = 2
    image    = "python:3.12-alpine"
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


# Example Pre-Deployment Job Output:
```log
module.service.null_resource.pre_deployment_jobs (local-exec): ═══════════════════════════════════════════════════════════════════════════════════
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] Found 1 pre-deployment job(s)
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] Mounting 1 config(s)
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] Mounting 2 secret(s)
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Starting pre-deployment job
module.service.null_resource.pre_deployment_jobs (local-exec): [CMD] docker service create --restart-condition=none --replicas=1 --detach --reserve-memory=128M --limit-memory=256M --reserve-cpu=0.1 --limit-cpu=0.2 --env cf__test__config=false --config source=tf-some-bot-api-well-known-jwks-json-54f1ee013b2796f1\,target=/run/configs/well-known.jwks.json\,mode=444 --secret source=tf-some-bot-api-app-f7ad8a63a88825ff\,target=/run/secrets/app.env\,mode=444 --secret source=tf-some-bot-api-database-a4d48d937f894ddb\,target=/run/secrets/database.env\,mode=444 --config source=tf-pre-deployment-some-bot-api-1-182def028613b13a.sh\,target=/srv/execute.sh\,mode=0755 --name tf-pre-deployment-some-bot-api-1-182def028613b13a docker.io/library/python:3.12-alpine /bin/sh /srv/execute.sh
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Found task: qwnz0o20vd9wgspph2l9csawy for service 87gljq7bukntgtvvi06f8gzig
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Task qwnz0o20vd9wgspph2l9csawy is starting; State: 'starting'
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Task qwnz0o20vd9wgspph2l9csawy has finished; State: 'complete'
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Attaching to container 6534173633c6 to capture logs; Timeout: 30s

module.service.null_resource.pre_deployment_jobs (local-exec): ═══════════════════════════════════════════════════════════════════════════════════
module.service.null_resource.pre_deployment_jobs (local-exec): [LOG] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Python 3.12.11
module.service.null_resource.pre_deployment_jobs (local-exec): [LOG] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): cf__test__config=false

module.service.null_resource.pre_deployment_jobs (local-exec): ═══════════════════════════════════════════════════════════════════════════════════
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Task 87gljq7bukntgtvvi06f8gzig has finished successfully! State: 'complete'
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Service 87gljq7bukntgtvvi06f8gzig removed successfully
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] [1/1] (tf-pre-deployment-some-bot-api-1-182def028613b13a): Pre-deployment job has finished successfully!
module.service.null_resource.pre_deployment_jobs (local-exec): [INFO] All pre-deployment jobs completed successfully!

module.service.null_resource.pre_deployment_jobs (local-exec): ═══════════════════════════════════════════════════════════════════════════════════
```