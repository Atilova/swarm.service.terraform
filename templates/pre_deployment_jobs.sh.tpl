#!/bin/bash
set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[38;5;238m'
NC='\033[0m'
SEPARATOR="═══════════════════════════════════════════════════════════════════════════════════"


bold() {
    echo -e "$${BOLD}$1$${NC}"
}


log() {
    echo -e "$${BLUE}[LOG]$${NC} $1" >&2
}


log_cmd() {
    echo -e "$${GRAY}[CMD] $1$${NC}" >&2
}


log_debug() {
    echo -e "$${CYAN}[DEBUG]$${NC} $1" >&2
}


log_info() {
    echo -e "$${GREEN}[INFO]$${NC} $1" >&2
}


log_warning() {
    echo -e "$${YELLOW}[WARNING]$${NC} $1" >&2
}


log_error() {
    echo -e "$${RED}[ERROR]$${NC} $1" >&2
}


log_blue_separator() {
    echo -e "\n$${BLUE}$${SEPARATOR}$${NC}" >&2
}


log_magenta_separator() {
    echo -e "\n$${MAGENTA}$${SEPARATOR}$${NC}" >&2
}


count_non_empty() {
    grep -cve '^\s*$'
}


get_docker_service_base_cmd() {
    echo "docker"
    echo "service"
    echo "create"

    echo "--restart-condition=none"
    echo "--replicas=1"
    echo "--detach"

    echo "--reserve-cpu=${service_resources_mib_cores.reserve_cpu}"
    echo "--reserve-memory=${service_resources_mib_cores.reserve_memory}MiB"
    echo "--limit-cpu=${service_resources_mib_cores.limit_cpu}"
    echo "--limit-memory=${service_resources_mib_cores.limit_memory}MiB"

    %{ for network in service_networks ~}
    echo "--network=${network}"
    log_info "Attaching to '${network}' network"
    %{ endfor ~}

    %{ if service_read_only_fs ~}
    echo "--read-only"
    log_info "Enabling read-only root filesystem"
    %{ endif ~}

    %{ for name, value in service_env ~}
    echo "--env"
    echo "${name}=${value}"
    %{ endfor ~}

    %{if length(service_configs) > 0 ~}
    log_info "Mounting ${length(service_configs)} config(s)"
    %{ endif ~}

    %{ for config in service_configs ~}
    echo "--config"
    echo "source=${config.source},target=${config.target},mode=${config.mode}"
    %{ endfor ~}

    %{if length(service_secrets) > 0 ~}
    log_info "Mounting ${length(service_secrets)} secret(s)"
    %{ endif ~}

    %{ for secret in service_secrets ~}
    echo "--secret"
    echo "source=${secret.source},target=${secret.target},mode=${secret.mode}"
    %{ endfor ~}
}


is_docker_service_exists() {
    if ! docker service inspect "$1" >/dev/null 2>&1; then
        return 1
    fi
}


get_docker_service_task_ids() {
    docker service ps "$1" -q 2>/dev/null
}


get_docker_service_task_state() {
    docker inspect "$1" --format '{{.Status.State}}' 2>/dev/null
}


get_docker_service_task_error() {
    docker inspect "$1" --format '{{.Status.Err}}' 2>/dev/null
}


get_docker_service_task_container_id() {
    local container_id=$(docker inspect "$1" --format '{{.Status.ContainerStatus.ContainerID}}' 2>/dev/null)
    docker ps -a -q --filter "id=$container_id"
}


get_docker_service_task_container_exit_code() {
    docker inspect "$1" --format='{{.State.ExitCode}}' 2>/dev/null
}


wait_for_docker_service_orchestrated() {
    local service_id="$1"
    local job_progress="$2"

    # TODO: Allow the Docker orchestrator to schedule tasks
    # This could be improved with a proper waiting mechanism and by inspecting replicas
    # simple sleep could also be added: 'sleep 1'
    # Another potential thing that: `docker service create --detach` might already wait and
    # return only when tasks are scheduled, but this needs to be confirmed.

    local service_task_ids=$(get_docker_service_task_ids "$service_id")
    local service_task_count=$(echo "$service_task_ids" | count_non_empty)
    if (( service_task_count <= 0 )); then
        log_error "$job_progress No tasks found for service $(bold "$service_id")"
        return 1
    fi

    if (( service_task_count > 1 )); then
        local service_task_list=$(echo "$service_task_ids" | paste -sd "," -)
        log_warning "$job_progress Multiple tasks found for service $(bold "$service_id"); IDs: $service_task_list"
    fi

    local task_id=$(echo "$service_task_ids" | head -n 1)
    log_info "$job_progress Found task: $(bold "$task_id") for service $(bold "$service_id")"

    echo "$task_id"
}


wait_for_docker_service_task_startup() {
    local task_id="$1"
    local job_progress="$2"

    local backoff_delay=1
    local backoff_started=$(date +%s)
    local backoff_timeout="${service_wake_up_backoff.timeout_seconds}"
    local backoff_delay_step="${service_wake_up_backoff.step}"
    local backoff_max_delay="${service_wake_up_backoff.max_delay}"

    while true; do
        local state=$(get_docker_service_task_state "$task_id")
        # log_debug "$job_progress Task $(bold "$task_id"); State: '$state'"

        case "$state" in
            "running")
                log_info "$job_progress Task $(bold "$task_id") is running; State: '$state'"
                return 0
                ;;
            "new"|"pending"|"assigned"|"accepted"|"ready"|"preparing"|"starting")
                log_info "$job_progress Task $(bold "$task_id") is starting; State: '$state'"
                ;;
            "failed"|"rejected"|"orphaned")
                log_error "$job_progress Task $(bold "$task_id") failed; State: '$state'"
                return 1
                ;;
            "remove")
                log_error "$job_progress Task $(bold "$task_id") removed; State: '$state'"
                return 1
                ;;
            "shutdown"|"complete")
                log_info "$job_progress Task $(bold "$task_id") has finished; State: '$state'"
                return 0
                ;;
            *)
                log_error "$job_progress Task $(bold "$task_id") unknown; State: '$state'"
                return 1
                ;;
        esac

        if (( backoff_timeout != -1 )); then
            local now=$(date +%s)
            if (( now - backoff_started >= backoff_timeout )); then
                log_error "$job_progress Service task $(bold "$task_id") wake up has timeouted; State: '$state'"
                return 124
            fi
        fi

        sleep "$backoff_delay"

        backoff_delay=$(( backoff_delay + backoff_delay_step ))
        if (( backoff_delay > backoff_max_delay )); then
            backoff_delay=$backoff_max_delay
        fi
    done
}


wait_for_docker_service_task_complete() {
    local container_id="$1"
    local job_timeout="$2"
    local job_progress="$3"

    log_info "$job_progress Attaching to container $(bold "$container_id") to capture logs; Timeout: $${job_timeout}s"
    log_blue_separator

    timeout "$${job_timeout}s" docker logs -f "$container_id" 2>&1 | while IFS= read -r line; do
        log "$job_progress $line"
    done
    local timeout_status=$?

    log_blue_separator
    # log_debug "Container $container_id timeout status: $timeout_status"

    if [ "$timeout_status" -eq 124 ]; then
        return 1
    fi
}


check_docker_service_task_completed_successfully() {
    local task_id="$1"
    local container_id="$2"
    local job_progress="$3"

    local task_state=$(get_docker_service_task_state "$task_id")
    local container_exit_code=$(get_docker_service_task_container_exit_code "$container_id")

    if (( "$container_exit_code" != 0 )); then
        local message="Task $(bold "$task_id") failed to complete gracefully; State: '$task_state'; "
        message+="Container $(bold "$container_id") exit code: '$container_exit_code'"

        log_error "$job_progress $message"
        return 1
    fi
}


print_docker_service_logs() {
    local service_id="$1"
    local job_progress="$2"

    if ! is_docker_service_exists "$service_id"; then
        log_warning "$job_progress Could not retrieve logs for service $(bold "$service_id")"
        return 0
    fi

    log_info "$job_progress Collected logs for service $(bold "$service_id")"

    log_blue_separator
    docker service logs --no-trunc "$service_id" 2>&1 | while IFS= read -r line; do
        log "$job_progress $line"
    done
    log_blue_separator
}


remove_docker_service() {
    local service_id="$1"
    local config_name="$2"
    local job_progress="$3"


    if ! docker service rm "$service_id" >/dev/null 2>&1; then
        log_warning "$job_progress Could not remove service $(bold "$service_id")"
    else
        log_info "$job_progress Service $(bold "$service_id") removed successfully"
    fi

    if ! docker config rm "$config_name" >/dev/null 2>&1; then
        log_warning "$job_progress Could not remove config $(bold "$config_name")"
    fi
}


handle_docker_service_task_startup_failure() {
    local service_id="$1"
    local task_id="$2"
    local job_progress="$3"

    local task_error=$(get_docker_service_task_error "$task_id")
    log_error "$job_progress Task $(bold "$task_id") failed to start; Error: '$task_error'"

    print_docker_service_logs "$service_id" "$job_progress"
}


handle_docker_service_missing_task_container() {
    local task_id="$1"
    local job_progress="$2"
    local message="Runtime container missing for task $(bold "$task_id")"

    local task_state=$(get_docker_service_task_state "$task_id")
    if [ -n "$task_state" ]; then
        message+="; State: '$task_state'"
    fi

    local task_error=$(get_docker_service_task_error "$task_id")
    if [ -n "$task_error" ]; then
        message+="; Error: '$task_error'"
    fi

    log_error "$job_progress $message"
}


handle_docker_service_task_timeouted() {
    local task_id="$1"
    local container_id="$2"
    local job_progress="$3"

    local task_state=$(get_docker_service_task_state "$task_id")
    local message="Task $(bold "$task_id") reached timeout waiting for container $(bold "$container_id"); State: '$task_state'"

    local task_error=$(get_docker_service_task_error "$task_id")
    if [ -n "$task_error" ]; then
        message+="; Error: '$task_error'"
    fi

    log_error "$job_progress $message"
}


monitor_docker_service() {
    local service_id="$1"
    local job_timeout="$2"
    local job_progress="$3"

    local task_id
    if ! task_id=$(wait_for_docker_service_orchestrated "$service_id" "$job_progress"); then
        return 1
    fi

    if ! wait_for_docker_service_task_startup "$task_id" "$job_progress"; then
        handle_docker_service_task_startup_failure "$service_id" "$task_id" "$job_progress"
        return 1
    fi

    local task_container_id=$(get_docker_service_task_container_id "$task_id")
    if [ -z "$task_container_id" ]; then
        handle_docker_service_missing_task_container "$task_id" "$job_progress"
        return 1
    fi

    if ! wait_for_docker_service_task_complete "$task_container_id" "$job_timeout" "$job_progress"; then
        handle_docker_service_task_timeouted "$task_id" "$task_container_id" "$job_progress"
        return 1
    fi

    if ! check_docker_service_task_completed_successfully "$task_id" "$task_container_id" "$job_progress"; then
        return 1
    fi

    local task_state=$(get_docker_service_task_state "$task_id")
    log_info "$job_progress Task $(bold "$service_id") has finished successfully! State: '$task_state'"
}


main() {
    local service_image="${service_image}"

    local -a docker_base_cmd
    mapfile -t docker_base_cmd < <(get_docker_service_base_cmd)

    %{ for idx, job in jobs ~}
    local job_hash=$(date +%s | sha256sum | cut -c1-16)
    local job_name="tf-pre-deployment-${service_name}-${idx+1}-$job_hash"
    local job_timeout="${job.timeout}"
    local job_execute_config_name="$job_name-sh"
    local job_progress="[${idx+1}/$total_jobs] ($job_name):"

    log_info "$job_progress Starting pre-deployment job"

    if ! echo '${job.command_b64}' | base64 --decode | docker config create "$job_execute_config_name" - > /dev/null 2>&1; then
        log_error "$job_progress Pre-deployment config creation failed, exit"
        exit 1
    fi

    local -a docker_cmd=( "$${docker_base_cmd[@]}" )
    docker_cmd+=( "--config" "source=$job_execute_config_name,target=/srv/execute.sh,mode=0755" )
    docker_cmd+=( "--name" "$job_name" )
    docker_cmd+=( "--entrypoint" "/bin/sh" )
    docker_cmd+=( "$service_image" "/srv/execute.sh" )

    log_cmd "$(printf '%q ' "$${docker_cmd[@]}")"

    local service_id="$("$${docker_cmd[@]}")"

    if ! monitor_docker_service "$service_id" "$job_timeout" "$job_progress"; then
        remove_docker_service "$service_id" "$job_execute_config_name" "$job_progress"
        log_error "$job_progress Pre-deployment job failed, exit"
        exit 1
    fi

    remove_docker_service "$service_id" "$job_execute_config_name" "$job_progress"
    log_info "$job_progress Pre-deployment job has finished successfully!"
    %{ endfor ~}
}

log_magenta_separator

total_jobs=${length(jobs)}
if [ "$total_jobs" -le 0 ]; then
    log_info "No pre-deployment jobs configured"
else
    log_info "Found $total_jobs pre-deployment job(s)"
    main
    log_info "All pre-deployment jobs completed successfully!"
fi

log_magenta_separator

exit 0
