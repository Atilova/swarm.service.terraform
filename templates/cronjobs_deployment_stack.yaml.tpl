%{ if length(cronjobs) > 0 ~}
services:
%{ for cronjob in cronjobs ~}
  ${cronjob.name}:
    image: ${service_image}
    entrypoint: ["/bin/sh", "/srv/execute.sh"]
    deploy:
      replicas: 0
      restart_policy:
        condition: none
      labels:
        - "swarm.cronjob.enable=true"
        - "swarm.cronjob.schedule=${cronjob.schedule}"
        - "swarm.cronjob.skip-running=true"
      resources:
        reservations:
          cpus: "${service_resources_mib_cores.reserve_cpu}"
          memory: "${service_resources_mib_cores.reserve_memory}MiB"
        limits:
          cpus: "${service_resources_mib_cores.limit_cpu}"
          memory: "${service_resources_mib_cores.limit_memory}MiB"
%{ if length(service_env) > 0 ~}
    environment:
%{ for name, value in service_env ~}
      - ${name}=${value}
%{ endfor ~}
%{ endif ~}
    configs:
%{ for config in service_configs ~}
      - source: ${config.source}
        target: ${config.target}
        mode: ${config.mode}
%{ endfor ~}
      - source: ${cronjob.command_config.source}
        target: /srv/execute.sh
        mode: ${cronjob.command_config.mode}
%{ if length(service_secrets) > 0 ~}
    secrets:
%{ for secret in service_secrets ~}
      - source: ${secret.source}
        target: ${secret.target}
        mode: ${secret.mode}
%{ endfor ~}
%{ endif ~}
%{ if length(service_networks) > 0 ~}
    networks:
%{ for network in service_networks ~}
      - ${network}
%{ endfor ~}
%{ endif ~}
%{ if service_read_only_fs ~}
    read_only: true
%{ endif ~}
%{ endfor ~}

configs:
%{ for config in service_configs ~}
  ${config.source}:
    external: true
%{ endfor ~}
%{ for cronjob in cronjobs ~}
  ${cronjob.command_config.source}:
    external: true
%{ endfor ~}

%{ if length(service_secrets) > 0 ~}
secrets:
%{ for secret in service_secrets ~}
  ${secret.source}:
    external: true
%{ endfor ~}
%{ endif ~}

%{ if length(service_networks) > 0 ~}
networks:
%{ for network in service_networks ~}
  ${network}:
    external: true
%{ endfor ~}
%{ endif ~}

%{ else ~}
services: {}
%{ endif ~}
