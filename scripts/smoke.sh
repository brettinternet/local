#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
broker_test_suffix="$$"
broker_test_project="local-broker-test-$broker_test_suffix"
broker_test_network="local-broker-test-$broker_test_suffix"
fixture_test_project="local-broker-fixture-$broker_test_suffix"
fixture_compose_file="$repository_root/tests/fixtures/compose.yaml"

export LOCAL_BROKER_BIND_IP=127.0.0.1
export LOCAL_BROKER_HTTP_PORT=0
export LOCAL_BROKER_HTTPS_PORT=0
export LOCAL_BROKER_NETWORK="$broker_test_network"
export LOCAL_BROKER_TEST_NETWORK="$broker_test_network"
export LOCAL_BROKER_TEST_ID="broker-test-$broker_test_suffix"

cleanup() {
  docker compose --project-name "$fixture_test_project" --file "$fixture_compose_file" down >/dev/null 2>&1 || true
  docker compose --project-name "$broker_test_project" --file "$repository_root/compose.yaml" down >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

probe_https() {
  local probe_host="$1"
  local probe_port="$2"
  local probe_output

  for _ in {1..30}; do
    if probe_output="$(
      curl \
        --fail \
        --silent \
        --show-error \
        --insecure \
        --resolve "$probe_host:$probe_port:127.0.0.1" \
        "https://$probe_host:$probe_port/" 2>/dev/null
    )" && grep -q '^Hostname:' <<<"$probe_output"; then
      return 0
    fi
    sleep 1
  done

  printf 'Timed out waiting for https://%s:%s/.\n' "$probe_host" "$probe_port" >&2
  return 1
}

command -v docker >/dev/null 2>&1 || {
  echo 'docker is unavailable. Run mise install and start Docker.' >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo 'curl is required for the smoke test.' >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo 'The Docker daemon is unavailable. Start Docker or run task docker:start.' >&2
  exit 1
}

docker compose \
  --project-name "$broker_test_project" \
  --file "$repository_root/compose.yaml" \
  up --detach --wait

docker compose \
  --project-name "$fixture_test_project" \
  --file "$fixture_compose_file" \
  up --detach

broker_http_port="$(
  docker compose \
    --project-name "$broker_test_project" \
    --file "$repository_root/compose.yaml" \
    port traefik 80 | awk -F: '{print $NF}'
)"
broker_https_port="$(
  docker compose \
    --project-name "$broker_test_project" \
    --file "$repository_root/compose.yaml" \
    port traefik 443 | awk -F: '{print $NF}'
)"

probe_https direct-smoke.localhost "$broker_https_port"
probe_https edge-smoke.localhost "$broker_https_port"

redirect_status="$(
  curl \
    --silent \
    --output /dev/null \
    --write-out '%{http_code}' \
    --resolve "direct-smoke.localhost:$broker_http_port:127.0.0.1" \
    "http://direct-smoke.localhost:$broker_http_port/"
)"
if [[ "$redirect_status" != "301" && "$redirect_status" != "308" ]]; then
  printf 'HTTP redirect returned %s, want a permanent redirect.\n' "$redirect_status" >&2
  exit 1
fi

printf 'PASS: direct HTTPS discovery, TLS passthrough, and HTTP redirect\n'
