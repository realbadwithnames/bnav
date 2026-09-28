# REVIEW: BNAV Fleet Telemetry cloud pack (Sep 27, 2026)

Scope: `docker-compose.yml`, `config.json`, `SETUP.md` and `.env.example`, reviewed against official Tesla sources fetched Sep 27, 2026.
Status legend: **CONFIRMED** (matches source) · **CORRECTED** (changed) · **[UNVERIFIED]** (sources don't settle it; original kept and tagged).

## Sources
- [R] fleet-telemetry README: https://github.com/teslamotors/fleet-telemetry/blob/main/README.md
- [EX] Example config: https://github.com/teslamotors/fleet-telemetry/blob/main/examples/server_config.json
- [CFG] Config struct and TLS: https://github.com/teslamotors/fleet-telemetry/blob/main/config/config.go
- [INIT] Config loader: https://github.com/teslamotors/fleet-telemetry/blob/main/config/config_initializer.go
- [LOG] Logger dispatcher: https://github.com/teslamotors/fleet-telemetry/blob/main/datastore/simple/logger.go
- [REC] Record types: https://github.com/teslamotors/fleet-telemetry/blob/main/telemetry/record.go
- [PROD] Dispatcher names: https://github.com/teslamotors/fleet-telemetry/blob/main/telemetry/producer.go
- [MAIN] Server entry: https://github.com/teslamotors/fleet-telemetry/blob/main/cmd/main.go
- [STAT] Status server: https://github.com/teslamotors/fleet-telemetry/blob/main/server/monitoring/status_server.go
- [DF] Dockerfile: https://github.com/teslamotors/fleet-telemetry/blob/main/Dockerfile
- [PROTO] Field names: https://github.com/teslamotors/fleet-telemetry/blob/main/protos/vehicle_data.proto
- [CSC] Cert checker: https://github.com/teslamotors/fleet-telemetry/blob/main/tools/check_server_cert.sh
- [HUB] Docker Hub tags: https://hub.docker.com/r/tesla/fleet-telemetry/tags (checked via https://hub.docker.com/v2/repositories/tesla/fleet-telemetry/tags)
- [GHR] Releases: https://github.com/teslamotors/fleet-telemetry/releases
- [FT] Fleet Telemetry docs: https://developer.tesla.com/docs/fleet-api/fleet-telemetry
- [AD] Available data: https://developer.tesla.com/docs/fleet-api/fleet-telemetry/available-data
- [VE] Vehicle endpoints: https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints
- [VK] Virtual keys: https://developer.tesla.com/docs/fleet-api/virtual-keys/developer-guide
- [ON] Onboarding: https://developer.tesla.com/docs/fleet-api/getting-started/what-is-fleet-api
- [BL] Billing and limits: https://developer.tesla.com/docs/fleet-api/billing-and-limits
- [PX] vehicle-command proxy: https://github.com/teslamotors/vehicle-command/blob/main/pkg/proxy/proxy.go

## docker-compose.yml

**Image: CORRECTED.** `tesla/fleet-telemetry:latest` became `tesla/fleet-telemetry:v0.9.4`.
- The image name is correct [R][HUB].
- v0.9.4 is the newest release (GitHub release published Jul 14, 2026 7:40 PM ET) [GHR].
- On Docker Hub, `v0.9.4` and `latest` had the same index digest `sha256:28c8b9e244b8…` when checked [HUB].
- The README says to "Get the latest docker image information from our docker hub" and shows `tesla/fleet-telemetry:<tag>` [R].
- The pin is our recommendation, for reproducibility. An optional digest pin is included as a comment.

**command: CONFIRMED.** `["/fleet-telemetry","-config","/etc/fleet-telemetry/config.json"]` is identical to the image CMD [DF]. The `-config` flag is defined in [INIT]. The README shows the `-config=` form, and both forms work with Go flags.

**Port 443 published: CONFIRMED.** The config uses port 443, and the README defaults to 443 [R][EX].

**Port 8080 published on 0.0.0.0: CORRECTED** to `127.0.0.1:8080:8080`.
- The status server listens on `:%d`, which is all interfaces inside the container, and serves `/status` → `ok` [STAT][MAIN].
- The original compose therefore exposed it publicly, contrary to SETUP's "localhost only".
- There is no need for it to be public.

**Volume mounts: CONFIRMED.** `/etc/fleet-telemetry/config.json` is the image's config path [DF]. The cert mount matches the `tls.*` paths, which are identical to [EX].

**`SUPPRESS_TLS_HANDSHAKE_ERROR_LOGGING=true`: CONFIRMED** [R].

**json-file log rotation: CONFIRMED (Docker setting, not a Tesla setting).** No change.

## config.json (unchanged; JSON can't carry comments)

Every key was checked against [CFG] and [R]:

| Key | Status | Note |
|---|---|---|
| host `0.0.0.0` | CONFIRMED | [CFG][EX] |
| port `443` | CONFIRMED | [CFG][EX] |
| status_port `8080` | CONFIRMED | Valid key; enables `/status` only when > 0 [CFG][MAIN] |
| log_level `info` | CONFIRMED | Allowed: trace, debug, info, warn, error [R] |
| json_log_enable `true` | CONFIRMED | [CFG] |
| namespace `bnav` | CONFIRMED | Valid; it is the topic prefix for Kafka/PubSub/Kinesis and has no effect on the logger [CFG][R] |
| reliable_ack `false` | **[UNVERIFIED] / no effect** | Listed in the README and example [R][EX], but there is **no `reliable_ack` field** in the Config struct (only `reliable_ack_sources`) [CFG]. The standard JSON decoder ignores unknown keys [INIT]. Left as-is because it is harmless. |
| transmit_decoded_records `true` | CONFIRMED | Valid; dispatchers get JSON instead of proto [R][CFG] |
| logger.verbose `true` | CONFIRMED | "include data types in the logs", 'V' records only [R][LOG] |
| rate_limit.enabled / message_limit | CONFIRMED | [CFG][EX] |
| rate_limit.message_interval_time `30` | CONFIRMED | In the struct and example [CFG][EX]; the README omits it |
| records: alerts / errors / V / connectivity → `logger` | CONFIRMED | Valid record types [REC]; `logger` is a valid dispatcher [PROD]; identical to [EX] |
| tls.server_cert / server_key | CONFIRMED | [CFG][EX] |
| mTLS CA / client cert | CONFIRMED: none needed | The server uses `RequireAndVerifyClientCert` against Tesla's prod CA embedded in the binary. `tls.ca_file` only *appends* a custom CA, and `use_default_eng_ca` switches to the eng CA [CFG]. The server refuses to start without `tls` [CFG]. |
| monitoring (absent) | OK | Optional [R] |

## SETUP.md

**Status port "localhost only" vs. "public IP, ports 443 + 8080": CORRECTED.** The VM table now says inbound 443 only, and a firewall step and a local `/status` check were added [STAT].

**TLS cert (full chain + key): CONFIRMED.** Added a note that no CA or client-cert config is needed [CFG].

**check_server_cert.sh: CONFIRMED and CLARIFIED.**
- `validate_server.json` needs `hostname`, `port` (default 443) and `ca` (the full chain). The script reads `.ca` with jq and writes it as the CA file, so it is PEM text, not a path [R][CSC].
- Needs `jq` and `openssl` [CSC].

**Step order: CORRECTED.**
- The original generated keys "After Gate 1 (app registered)". The public key must be hosted **before** calling register [R steps 2–6][ON][VK].
- Added the missing vehicle-authorization step, needed before pairing [VK].
- Added `skipped_vehicles` and `fleet_telemetry_errors` diagnostics [VE][R].
- Order now: app → key pair → host public key → partner token → register → (server + cert check) → authorize vehicles → pair virtual key → proxy with private key → fleet_telemetry_config → `synced: true` [R][FT].

**App client type: ADDED.** The README recommends "Authorization Code and Machine-to-Machine"; M2M only is for business accounts that own vehicles [R].

**Public key path `/.well-known/appspecific/com.tesla.3p.public-key.pem`: CONFIRMED** [ON][VK][R]. Added that it must *remain* available [VK][FT].

**Virtual key pairing `tesla.com/_ak/<domain>`: CONFIRMED** [VK][FT].
- Added the optional `?vin=` parameter [VK].
- Added the prerequisite that the app is authorized with `vehicle_device_data`, `vehicle_cmds` **or** `vehicle_location` [VK].
- Added that B2B-program vehicles get the key automatically if they have < 20 keys and don't require the command protocol [VK].

**Proxy with the private key → POST fleet_telemetry_config: CONFIRMED** [VE][FT][R]. The proxy signs the config locally and forwards it to `fleet_telemetry_config_jws` [PX]. Request-body schema: [UNVERIFIED] (not rendered in the fetched docs).

**Field names: CONFIRMED.** All nine exist with the exact names given: Location, DestinationLocation, DestinationName, MinutesToArrival, MilesToArrival, VehicleSpeed, Gear, GpsState, RouteLine [AD][PROTO]. The proto marks the nav/route fields as firmware 2024.26+ [PROTO].

**Firmware ≥ 2024.26: CONFIRMED** for the proxy path [VE][FT].
- Added: Intel Atom S/X need ≥ 2025.20; pre-2018 S/X are unsupported [VE].
- The README's "2023.20.6" applies to the legacy CSR path only [FT].

**Billing warning: CONFIRMED.** The default limit is $0; exceeding it suspends usage and removes telemetry configs, which are not restored [BL].

**VM sizing (1 vCPU, 2 GB): [UNVERIFIED].** Not from Tesla docs; kept.

**"QAI garage API" row: kept.** Note that the handoff retired the name "QAI". This is the user's lab, and I left it unchanged.

**Security: ADDED.** Sanitize payloads and allow-list VINs downstream [R]. There is no allow-list key in [CFG].

## .env.example

**CLARIFIED.** The compose file doesn't read these variables, so they are reference only. Added a private-key warning. The public key path is CONFIRMED [ON].

## Scopes for `fleet_telemetry_config`

- **CONFIRMED:** `vehicle_location` is required for Location, OriginLocation, DestinationLocation, DestinationName, RouteLine, GpsState and GpsHeading [FT][VE].
- **CONFIRMED:** configs are removed if a required scope is revoked [FT].
- **[UNVERIFIED]:** the scope for MinutesToArrival, MilesToArrival, VehicleSpeed and Gear, and whether the config endpoint itself requires `vehicle_cmds`. Partial evidence: key pairing needs any one of vehicle_device_data / vehicle_cmds / vehicle_location [VK], and the proxy signs the config with the app key rather than via a command scope [PX]. Neither states the endpoint's scope.
- **[UNVERIFIED]:** the per-vehicle app limit. "Five third-party applications" [FT] and the create endpoint's `max_configs` "five configurations" [VE] conflict with the get endpoint's "only allows 3 configurations" [VE].
