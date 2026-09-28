#!/usr/bin/env bash
# Generate the EC P-256 (prime256v1) key pair for the BNAV Tesla application.
#
# The commands are Tesla's, not a local variant:
# https://developer.tesla.com/docs/fleet-api/getting-started/what-is-fleet-api
# https://developer.tesla.com/docs/fleet-api/virtual-keys/developer-guide
# https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md
# The developer guide says the vehicle only supports prime256v1 keys.
#
# Writes private-key.pem (mode 0600) and public-key.pem. Does not print the
# private key. Refuses to overwrite unless --force is passed.
#
# Usage:
#   telemetry/scripts/generate-keypair.sh [--force] [output-dir]
# Default output directory: telemetry/keys/ (gitignored).

set -euo pipefail

force=0
out=""

usage() {
  echo "Usage: $0 [--force] [output-dir]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *)
      if [[ -n "$out" ]]; then
        echo "unexpected argument: $1" >&2
        usage
      fi
      out="$1"
      shift
      ;;
  esac
done

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
default_out=$(cd "$script_dir/.." && pwd)/keys
out="${out:-$default_out}"
mkdir -p "$out"

priv="$out/private-key.pem"
pub="$out/public-key.pem"

if [[ "$force" -eq 0 && ( -e "$priv" || -e "$pub" ) ]]; then
  echo "refusing to overwrite $priv or $pub (pass --force)" >&2
  exit 1
fi

umask 077
openssl ecparam -name prime256v1 -genkey -noout -out "$priv"
openssl ec -in "$priv" -pubout -out "$pub"
chmod 600 "$priv"
chmod 644 "$pub"

# Confirm the public key is prime256v1 without printing private key material.
curve=$(openssl pkey -pubin -in "$pub" -text -noout | awk '/ASN1 OID:/ { print $3; exit }')
if [[ "$curve" != "prime256v1" ]]; then
  echo "generated public key curve is '$curve', expected prime256v1" >&2
  exit 1
fi

cat <<EOF
Wrote:
  $priv  (mode 0600, never commit, never place on a web server)
  $pub   (this is the file to host)

Host the public key, and leave it hosted, over HTTPS at:
  https://<app-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem

Tesla's Fleet Telemetry troubleshooting says pairing reports that the
application has not registered if this file is no longer at the
/.well-known/ path. The register domain must match the root domain of the
app's allowed origins. See telemetry/SETUP.md.

Do not commit private-key.pem, public-key.pem, tls.key, or partner tokens.
EOF
