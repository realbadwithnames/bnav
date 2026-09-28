#!/usr/bin/env bash
# Fail if a tracked file looks like a private key, TLS key, or partner token.
# Gitignore is the first line of defense. This is the backstop for commits.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

status=0

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  base=$(basename "$path")

  case "$base" in
    *.pem|*.key|*.crt|private-key.pem|public-key.pem|tls.key|tls.crt|validate_server.json|.env)
      echo "tracked secret-like file: $path" >&2
      status=1
      ;;
    partner-token|partner_token|*.token|partner-token.*|partner_token.*)
      echo "tracked partner-token file: $path" >&2
      status=1
      ;;
  esac

  if [[ -f "$path" ]] && grep -I -E -q "BEGIN (EC |RSA |OPENSSH )?PRIVATE KEY" "$path"; then
    echo "private-key block in tracked file: $path" >&2
    status=1
  fi
done < <(git ls-files)

if [[ "$status" -ne 0 ]]; then
  echo "refusing: private keys, certs, or partner tokens must not be tracked" >&2
  exit 1
fi

echo "no tracked private keys, certs, or partner-token files"
