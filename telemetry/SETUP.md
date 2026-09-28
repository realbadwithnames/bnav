# BNAV Fleet Telemetry — cloud box (reviewed Sep 27, 2026; logging and prep updated Sep 28, 2026)

Not the Windows laptop. Vehicles will not stream to a sleeping Victus.

The receiver image is pinned to the release tag `tesla/fleet-telemetry:v0.9.4`, not `:latest`. Checked Sep 28, 2026: GitHub's latest release is [v0.9.4](https://github.com/teslamotors/fleet-telemetry/releases/tag/v0.9.4) (published 2026-07-14T23:40:47Z), and the Docker Hub tag `v0.9.4` exists with the same index digest as `:latest` that day (`sha256:28c8b9e244b842a3d7443567cfa385b4db20cf533b8dee3411ce6fe540eb67e2`, [tags](https://hub.docker.com/r/tesla/fleet-telemetry/tags)). v0.9.4 is used because it is the newest published release tag. `:latest` matches it today and would move without a commit. The [fleet-telemetry README](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md) says to take the image tag from Docker Hub.

The official install path is a public FQDN, mTLS terminated on this process, then a dispatcher. For Gate 2 the dispatcher is the stdout logger. Kafka comes when two cars are boring.
See REVIEW.md for the Sep 27 review and the Sep 28 addendum.

Phase 1 is read-only: Fleet API scopes `vehicle_device_data` and `vehicle_location` only. This pack does not send vehicle commands.

## What Docker is for

| Job | Where |
|---|---|
| Local garage lab (API + Postgres) | Your laptop, if you want that lab |
| Tesla Fleet Telemetry receiver | A small always-on VPS you control (1 vCPU, 2 GB [sizing not from Tesla docs], public IP, **inbound 443 only**) |

Do not run this image on the laptop.

## VM provisioning runbook

Repo-side only until a VM exists. Placeholders (`telemetry.example.com`, `<app-domain>`) are not a real deployment.

1. **VM.** Provision a small always-on Linux VPS with a public IPv4 address. Sizing of 1 vCPU / 2 GB is [UNVERIFIED] (not stated in Tesla's docs). Do not use the laptop.
2. **DNS A record.** Create an A record for the telemetry FQDN (example shape: `telemetry.example.com`) that points at the VM's public IPv4. Tesla's install steps start by allocating an FQDN used in the server and in the vehicle configuration ([README install step 1](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md)). The config `hostname` must match the root domain (second-level + first-level domain) of the registered application (field description on [vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints)). Never use `localhost`.
3. **Docker Engine, not Docker Desktop.** Install Docker Engine on the VM using Docker's install guide for that distribution: <https://docs.docker.com/engine/install/>. Do not install Docker Desktop. Confirm `docker compose version` works.
4. **Firewall.** Allow inbound TCP 443 and your SSH port. Do not open 8080. Compose publishes 443 on all host interfaces and publishes 8080 only on `127.0.0.1`. `config.json` does not set `monitoring`, and v0.9.4 starts the Prometheus listener only when `monitoring` is set ([cmd/main.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/cmd/main.go)). If you add `monitoring.prometheus_metrics_port` later, the server defaults that listener to `127.0.0.1` inside the container ([metrics_server.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/server/monitoring/metrics_server.go)). Do not publish it.
5. **Copy this folder** to the VM (for example `/opt/bnav/telemetry`). Do not copy `keys/`, `.env`, or any `*.pem` private key onto a public web root.
6. **Certificate.** Put a real certificate for the telemetry FQDN in this folder on the VM, as copies, not symlinks. Let's Encrypt `live/` links will not resolve inside the container.
   - `certs/tls.crt` — full chain
   - `certs/tls.key` — private key, mode `0400`, owned by UID 65532
   - Neither file is committed. `.gitignore` ignores `*.key`, `*.crt`, and `certs/*` except `certs/.gitkeep`.
   - The v0.9.4 image runs from `gcr.io/distroless/cc-debian11:nonroot` ([Dockerfile](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/Dockerfile)). The Sep 27 smoke test found that the process is UID 65532 and that a `0600` key crash-loops with `panic: open /etc/certs/server/tls.key: permission denied`. After every renewal:

     ```bash
     sudo chown 65532:65532 certs/tls.key
     sudo chmod 0400 certs/tls.key
     ```

   - No CA or client-cert config is needed in `config.json`. The server requires and verifies vehicle client certs against Tesla's CA, which is built into the binary. `tls.ca_file` is only for appending a custom CA ([config.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/config/config.go)).
7. **Start.** From the `telemetry/` directory:

   ```bash
   docker compose up -d
   docker compose ps
   ```

   `bnav-fleet-telemetry` must stay `Up`, not `Restarting`. On the VM:

   ```bash
   curl --fail --silent http://127.0.0.1:8080/status
   ```

   That prints `ok` ([status_server.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/server/monitoring/status_server.go)). From anywhere else, port 8080 must not answer. From the public internet, TCP 443 must accept a TLS handshake.
8. **Tesla's cert check, from a laptop** (not on the vehicle). Install `jq` and `openssl`. Copy `tools/check_server_cert.sh` from the v0.9.4 tree ([script](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/tools/check_server_cert.sh)). Create `validate_server.json` (do not commit it; it is gitignored) with:
   - `hostname`: the telemetry FQDN
   - `port`: `443` (the script defaults this to 443)
   - `ca`: the full certificate chain as PEM text, not a file path ([README step 8](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md))

   ```bash
   ./check_server_cert.sh validate_server.json
   ```

   Success text from the script is `The server certificate is valid.` A partial chain prints a warning. Do not point this check at localhost.

## Tesla-side steps (in order)

These stay blocked until the Fleet API application is approved. Nothing here calls Tesla.

1. Gate 1: create the developer app on <https://developer.tesla.com>. The fleet-telemetry README recommends "Authorization Code and Machine-to-Machine". M2M only is for business accounts that own vehicles ([README step 1](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md)). Request only `vehicle_device_data` and `vehicle_location`. Do not request command scopes.
2. Generate the key pair **before** calling register. From a trusted machine, not the public web root:

   ```bash
   telemetry/scripts/generate-keypair.sh
   ```

   That runs Tesla's commands (`openssl ecparam -name prime256v1` then `openssl ec -pubout`) and writes `telemetry/keys/private-key.pem` and `telemetry/keys/public-key.pem`. The developer guide says the vehicle only supports prime256v1 keys ([virtual keys](https://developer.tesla.com/docs/fleet-api/virtual-keys/developer-guide)).
3. Host `public-key.pem` as described in the next section. Leave it hosted.
4. Get a partner token ([partner tokens](https://developer.tesla.com/docs/fleet-api/authentication/partner-tokens)), then call the register endpoint for each region of operation, including NA ([what is Fleet API, step 4](https://developer.tesla.com/docs/fleet-api/getting-started/what-is-fleet-api), [register](https://developer.tesla.com/docs/fleet-api/endpoints/partner-endpoints)). Store the token outside this repo.
5. Authorize the vehicles: Tesla for Business consent, or a partner token for your own fleet, with `vehicle_device_data` and `vehicle_location` only.
6. Pair the virtual key on each vehicle at `https://tesla.com/_ak/<app-domain>` (optionally `?vin=<VIN>`). Before pairing, the user must have authorized the app with `vehicle_device_data`, `vehicle_cmds`, or `vehicle_location` ([virtual keys](https://developer.tesla.com/docs/fleet-api/virtual-keys/developer-guide)). Vehicles bought through Tesla's B2B program may get the key automatically when they have fewer than 20 keys and do not require the command protocol (same page). This pilot does not request `vehicle_cmds`.
7. Run the vehicle-command HTTP proxy with the **private** key. This repo does not ship the proxy and does not send commands. The proxy signs the config and forwards it ([proxy.go `handleFleetTelemetryConfig`](https://github.com/teslamotors/vehicle-command/blob/82d5e238d0dcc4ebce98a4dc125df3b9eb2ba437/pkg/proxy/proxy.go), read Sep 28, 2026).
8. Through the proxy, `POST /api/1/vehicles/fleet_telemetry_config` using [fleet_telemetry_config.template.json](fleet_telemetry_config.template.json). `hostname` is the telemetry FQDN, never localhost.
9. Wait for `synced: true` on `GET /api/1/vehicles/{vin}/fleet_telemetry_config`. Check `skipped_vehicles` (`missing_key`, `unsupported_hardware`, `unsupported_firmware`, `max_configs`) and use `fleet_telemetry_errors` to diagnose ([vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints)).

## Host the application public key

Serve the generated `public-key.pem` at this exact URL over HTTPS:

`https://<app-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem`

Sources: [what is Fleet API, step 3](https://developer.tesla.com/docs/fleet-api/getting-started/what-is-fleet-api), [virtual keys](https://developer.tesla.com/docs/fleet-api/virtual-keys/developer-guide), [register](https://developer.tesla.com/docs/fleet-api/endpoints/partner-endpoints).

Rules from those pages:

- `<app-domain>` is the application domain on developer.tesla.com. It can be the same host as the telemetry FQDN or a different host. Both need working TLS.
- The register endpoint's domain must match the root domain of `allowed_origins` on developer.tesla.com. Tesla's example: `123.abc.com` can be used for an allowed origin of `www.abc.com` ([partner endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/partner-endpoints)).
- The file must **remain** available. Pairing reports that the application has not registered if the public key is no longer at the `/.well-known/` path on the registration domain ([Fleet Telemetry overview](https://developer.tesla.com/docs/fleet-api/fleet-telemetry)).
- `private-key.pem` is never hosted and never committed. It is only for the vehicle-command proxy.

The docs do not specify a web server. Any static host that returns the PEM bytes at that path is enough. Confirm from outside the host:

```bash
curl --fail --silent --show-error \
  "https://<app-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem"
```

The body should be the public key file. Re-run this check after any deploy. A 404 or a TLS error blocks register and later pairing.

## fleet_telemetry_config template

[fleet_telemetry_config.template.json](fleet_telemetry_config.template.json) is the body to POST to `/api/1/vehicles/fleet_telemetry_config` through the vehicle-command proxy. Do not POST it to Tesla until Gate 1 is approved and the pre-flight checklist below is done. Replace every placeholder. Do not commit the filled file if it contains a real VIN or certificate.

Shape, verified Sep 28, 2026 against the create-endpoint specification published with [vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints) (the expandable request schema on that page):

| JSON | Required | Notes from that spec |
|---|---|---|
| `vins` | yes | Array of VIN strings. The parameter text says it is recommended to pass only one VIN at a time. |
| `config` | yes | Object the proxy signs. The proxy reads `vins` and `config`, overwrites `aud` and `iss` if present, and forwards a JWS to `POST /api/1/vehicles/fleet_telemetry_config_jws` ([proxy.go](https://github.com/teslamotors/vehicle-command/blob/82d5e238d0dcc4ebce98a4dc125df3b9eb2ba437/pkg/proxy/proxy.go)). Tesla says it is not recommended to call the JWS endpoint directly ([vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints)). |
| `config.hostname` | yes | Spec example `test-telemetry.com`. Description: URL of the fleet-telemetry server, and it must match the root domain of the registered application. Template uses `telemetry.example.com`. Never `localhost`. |
| `config.port` | yes | Spec example is `4443`. Description: server port. This receiver listens on **443**, which is also the README default, so the template uses `443`. |
| `config.ca` | yes | Spec example is a PEM certificate string, not a file path. Description: "Certificate authority cert for fleet-telemetry server". Paste the PEM text in place of `PASTE_PEM_CA_CERTIFICATE_HERE`. The cert-check file uses the full chain as PEM text ([README step 8](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md)). The overview says the host and CA in the configuration must be compatible with the server as checked by `check_server_cert.sh`. |
| `config.fields.<Field>` | yes, per field you stream | Each value requires integer `interval_seconds`. Optional `minimum_delta`, `resend_interval_seconds`, and `include_fields` are documented on the same schema and are omitted here. |
| `config.exp` | no | Omitted. The spec says that if it is not set, the config is valid indefinitely. |
| `config.alert_types` | no | Omitted. Not part of the Gate 2 field list. |
| `config.delivery_policy` | no | Omitted. |

The template's `interval_seconds` of `10` matches Tesla's published sample for `VehicleSpeed` and `Location` on the [Fleet Telemetry overview](https://developer.tesla.com/docs/fleet-api/fleet-telemetry). It is a template starting value, not a requirement for the other fields. Change it before sending. A field is sent only after `interval_seconds` has elapsed **and** the value has changed (same page). `minimum_delta` for numeric fields, and for location in meters, is a separate option ([announcements, 2025-01-09](https://developer.tesla.com/docs/fleet-api/announcements); location support is also in the overview changelog for client 1.0.0).

Field names in the template exist with those exact spellings on [Available Data](https://developer.tesla.com/docs/fleet-api/fleet-telemetry/available-data) and in [vehicle_data.proto at v0.9.4](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/protos/vehicle_data.proto):

| Field | Category on Available Data | Proto note |
|---|---|---|
| Location | Location | — |
| DestinationLocation | Location | firmware 2024.26 or later |
| DestinationName | Location | firmware 2024.26 or later |
| MinutesToArrival | Location | firmware 2024.26 or later |
| MilesToArrival | Location | firmware 2024.26 or later |
| VehicleSpeed | Driving | — |
| Gear | Driving | — |
| GpsState | Location | — |
| RouteLine | Location | firmware 2024.26 or later. Available Data: base64 polyline, precision 6. |

`vehicle_location` is required for Location, OriginLocation, DestinationLocation, DestinationName, RouteLine, GpsState, and GpsHeading ([overview](https://developer.tesla.com/docs/fleet-api/fleet-telemetry), [vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints)). The scope for MinutesToArrival, MilesToArrival, VehicleSpeed, and Gear is [UNVERIFIED]. None of those four is in that `vehicle_location` list. The create endpoint's published security entry lists `vehicle_device_data` and `vehicle_location` and does not list `vehicle_cmds` (same vehicle-endpoints specification).

A vehicle share with `granular_access.hide_private` set to true cannot include those location fields. Creating a config that includes them is rejected with `403` (`location access not granted`) even if `vehicle_location` was granted (same pages).

The create response can include `skipped_vehicles` with `missing_key`, `unsupported_hardware`, `unsupported_firmware`, and `max_configs`. `max_configs` on create means the vehicle already has five configurations. The get endpoint says the vehicle only allows 3 configurations. Both sentences are on [vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints) as of Sep 28, 2026. The overview says five third-party applications ([overview](https://developer.tesla.com/docs/fleet-api/fleet-telemetry)). Treat the conflict as unresolved.

## Gate 2 pre-flight checklist

Do this before the first `fleet_telemetry_config` POST. Approval of the developer app is still required; this list is the repo-side reminder.

- [ ] Billing limit is **above $0**, and a payment method is configured, before the first config is sent. The default limit is 0. The limit can be increased once a payment method is added. Apps that exceed the limit or have no payment method are disabled. Exceeding the limit removes Fleet Telemetry configs, and they are not restored ([billing and limits](https://developer.tesla.com/docs/fleet-api/billing-and-limits)).
- [ ] Both vehicles are on firmware **2024.26 or later** for the vehicle-command proxy path. Intel Atom Model S/X need **2025.20 or later**. Pre-2018 Model S/X are unsupported hardware ([vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints), [overview](https://developer.tesla.com/docs/fleet-api/fleet-telemetry)). `POST /api/1/vehicles/fleet_status` returns `firmware_version` ([vehicle endpoints](https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints)).
- [ ] `public-key.pem` still answers at `https://<app-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem` over valid TLS.
- [ ] Virtual key is paired (`https://tesla.com/_ak/<app-domain>`). The authorizing account is not a `hide_private` share if the config includes location fields.
- [ ] Receiver is up, `curl http://127.0.0.1:8080/status` on the VM prints `ok`, 8080 is not reachable from the internet, and `check_server_cert.sh` reports the server certificate valid.
- [ ] Template `hostname` is the telemetry FQDN (not localhost) and its root domain matches the registered application. `port` is `443`. `ca` is the PEM CA cert, not a path.
- [ ] `vins` contains one placeholder-free VIN per request. The private key stays on the proxy only.
- [ ] After the POST, `synced` is `true` for each vehicle. Logger output for a live VIN is a Gate 2 check: turn on the debug toggle below, confirm the requested fields, then turn it off and drop the logs.

## Do not

- Expose the private key, or host it anywhere.
- Commit `private-key.pem`, any `*.pem` private key, `tls.key`, `tls.crt`, `validate_server.json`, or a partner token. `.gitignore` covers those names. `telemetry/scripts/check-no-secrets.sh` fails if a tracked file matches.
- Publish port 8080, or any metrics port, on `0.0.0.0`.
- Point vehicles at localhost.
- Leave the Tesla billing limit at $0 and then stream.
- Add Kafka until logger output is proven on a live VIN.
- Send vehicle commands. This pack does not include them.
- Trust payloads blindly. The README says to sanitize data and allow-list VINs downstream ([README, Security and Privacy](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/README.md)).

## Config notes

- `reliable_ack` in `config.json` is a compatibility no-op. It appears in Tesla's README and example config, but the current server code does not read it (only `reliable_ack_sources` exists). It provides **no** delivery guarantee. See REVIEW.md.
- `log_level` is `warn` and `logger.verbose` is `false` on purpose. See the next section.

## Privacy: telemetry log retention

This section is the logging bound for issue 6. It is not the one-page privacy summary.

What the v0.9.4 logger actually writes ([logger.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/datastore/simple/logger.go), [payload.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/datastore/simple/transformers/payload.go)):

- Every produced record is an Info-level activity log named `record_payload`. The log fields include `vin` plus the decoded payload.
- For `V` records the payload includes `Vin` and, when a location field was streamed, latitude and longitude. `logger.verbose` only wraps values with protobuf type names. It does **not** remove the VIN or the coordinates. Connectivity records also include `Vin` ([vehicle_connectivity.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/datastore/simple/transformers/vehicle_connectivity.go)).
- `ActivityLog` calls logrus `Info` ([logger.go](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/logger/logger.go)). `log_level` is applied with `logrus.SetLevel` ([config.go `configureLogger`](https://github.com/teslamotors/fleet-telemetry/blob/v0.9.4/config/config.go)). `warn` therefore drops those Info lines.

**Default retention**

- Record payloads, including VIN and precise location, are not emitted (`log_level: warn`, `logger.verbose: false`).
- Error lines still emit. A transform failure (`record_logging_error`) includes the VIN and does not include the location payload.
- Docker's `json-file` driver keeps whatever is emitted, with `max-size: 5m` and `max-file: 2`. That is a **10 MB** cap (2 × 5 MB). When a roll would leave more than two files, Docker removes the oldest file. There is no time-based retention in this driver ([json-file options](https://docs.docker.com/engine/logging/drivers/json-file/)). These numbers are an operator cap, not a Tesla requirement. The previous cap was 5 × 20 MB.

**Gate 2 debug toggle**

Use this only while confirming a live VIN, then turn it off.

1. In `config.json`, set `log_level` to `info` and `logger.verbose` to `true`.
2. `docker compose up -d` so the process reloads the file (the config is read at startup).
3. Capture the lines you need (`docker compose logs --tail=100 fleet-telemetry`). With `info`, `record_payload` JSON includes VIN and location. `verbose: true` adds type names on top of that.
4. Set `log_level` back to `warn` and `logger.verbose` back to `false`.
5. Drop the debug logs with the container. Docker says not to edit the json log files with other tools ([same page](https://docs.docker.com/engine/logging/drivers/json-file/)). From the `telemetry/` directory:

   ```bash
   docker compose down
   docker compose up -d
   ```

While the toggle is on, the same 10 MB cap applies, so a busy stream will roll quickly. Copy the sample you need before you `down`.
