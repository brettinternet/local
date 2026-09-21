#!/usr/bin/env bash

set -euo pipefail

share_host="${LOCAL_BROKER_SHARE_HOST:-}"

if [[ -z "$share_host" ]]; then
  printf '%s\n' 'Set HOST to the route hostname, for example: task share HOST=app.local.example.test' >&2
  exit 2
fi

if [[ ! "$share_host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || [[ "$share_host" == *..* ]]; then
  printf 'HOST must be one hostname without a scheme, port, or path: %s\n' "$share_host" >&2
  exit 2
fi

bind_ip="${LOCAL_BROKER_BIND_IP:-127.0.0.1}"
https_port="${LOCAL_BROKER_HTTPS_PORT:-443}"

case "$bind_ip" in
  0.0.0.0 | :: | '[::]') origin_host=127.0.0.1 ;;
  *) origin_host="$bind_ip" ;;
esac

origin_url="https://${origin_host}:${https_port}"

printf 'Temporarily sharing https://%s through Cloudflare.\n' "$share_host"
printf '%s\n' 'Anyone with the generated URL can reach this route. Press Ctrl-C to stop sharing.'
printf '%s\n\n' 'The public trycloudflare.com URL will appear below.'

exec cloudflared tunnel \
  --config <(printf '{}\n') \
  --url "$origin_url" \
  --http-host-header "$share_host" \
  --origin-server-name "$share_host"
