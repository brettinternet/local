#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
domains_file="$repository_root/certs/domains.txt"
certificate_file="$repository_root/certs/local.pem"
certificate_key_file="$repository_root/certs/local-key.pem"
certificate_names=()

if [[ ! -f "$domains_file" ]]; then
  printf 'Missing %s. Copy examples/domains.txt there and replace the example names.\n' "$domains_file" >&2
  exit 1
fi

while IFS= read -r certificate_name || [[ -n "$certificate_name" ]]; do
  certificate_name="${certificate_name%$'\r'}"
  certificate_name="${certificate_name#"${certificate_name%%[![:space:]]*}"}"
  certificate_name="${certificate_name%"${certificate_name##*[![:space:]]}"}"
  [[ -z "$certificate_name" || "$certificate_name" == \#* ]] && continue
  certificate_names+=("$certificate_name")
done <"$domains_file"

if (( ${#certificate_names[@]} == 0 )); then
  printf '%s contains no certificate names.\n' "$domains_file" >&2
  exit 1
fi

if ! command -v mkcert >/dev/null 2>&1; then
  echo 'mkcert is unavailable. Run mise install or install mkcert separately.' >&2
  exit 1
fi

mkcert -install
mkcert \
  -cert-file "$certificate_file" \
  -key-file "$certificate_key_file" \
  "${certificate_names[@]}"

printf 'Generated %s and %s for %d names.\n' \
  "$certificate_file" "$certificate_key_file" "${#certificate_names[@]}"
