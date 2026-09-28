# BNAV Fleet Telemetry — cloud box (reviewed Sep 27, 2026)

Not the Windows laptop. Vehicles will not stream to a sleeping Victus.

Tesla publishes `tesla/fleet-telemetry` on Docker Hub (pinned here to `v0.9.4`). The official install path: a public FQDN, mTLS terminated on this process, then a dispatcher. For Gate 2 we log JSON to stdout. Kafka comes when two cars are boring.
See REVIEW.md for what changed and why.

## What Docker is for

| Job | Where |
|---|---|
| QAI garage API + Postgres | Your laptop, if you want that lab |
| Tesla Fleet Telemetry receiver | A small always-on VPS you control (1 vCPU, 2 GB [sizing not from Tesla docs], public IP, **inbound 443 only**) |

Do not run this image on the laptop.

## VM steps

1. Buy a cheap cloud VM. Point the `telemetry.<your-domain>` A-record at it.
2. Install Docker Engine on the VM (not Docker Desktop).
3. Firewall: allow inbound TCP 443 (plus your SSH). **Do not open 8080.** Compose binds it to 127.0.0.1 only.
4. Copy this folder to the VM.
5. Put a real cert on the FQDN:
   - `certs/tls.crt` (full chain)
   - `certs/tls.key`
   - Copy the real files into `certs/`, not symlinks. Let's Encrypt `live/` links will not resolve inside the container.
   - The container runs as UID 65532 and must be able to read the key: `sudo chown 65532:65532 certs/tls.key && sudo chmod 0400 certs/tls.key`. Repeat after every cert renewal. A normal 0600 key makes the container crash-loop with `panic: open /etc/certs/server/tls.key: permission denied` (found in the Sep 27 smoke test).
   - No CA or client-cert config is needed. The server requires and verifies vehicle client certs against Tesla's CA, which is built into the binary. `tls.ca_file` is only for appending a custom CA.
6. `docker compose up -d`, check that `docker compose ps` shows `Up` (not `Restarting`), then on the VM run `curl http://127.0.0.1:8080/status` (it should print `ok`).
7. From a laptop, run Tesla's `tools/check_server_cert.sh validate_server.json`. The JSON holds `hostname`, `port` (443) and `ca` (the full chain as a PEM string). The script needs `jq` and `openssl`.

## Tesla-side steps (in order)

1. Gate 1: create the developer app on developer.tesla.com. The fleet-telemetry README recommends "Authorization Code and Machine-to-Machine". M2M only is for business accounts that own vehicles.
2. Generate the key pair **before** calling register:

```
openssl ecparam -name prime256v1 -genkey -noout -out private-key.pem
openssl ec -in private-key.pem -pubout -out public-key.pem
```

3. Host `public-key.pem` at:

`https://<app-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem`

That domain is the **application** domain registered on developer.tesla.com. It can be the same host as `telemetry.<domain>` or a different one; both need working TLS. The public key must *remain* available, because pairing fails if it disappears.

4. Get a partner token, then call the register endpoint (NA region).
5. Authorize the vehicles: Tesla for Business consent (or a partner token for your own fleet), with `vehicle_device_data` + `vehicle_location`.
6. Pair the virtual key on each vehicle at `https://tesla.com/_ak/<app-domain>` (optionally `?vin=<VIN>`). Before pairing, the user must have authorized the app with `vehicle_device_data`, `vehicle_cmds` or `vehicle_location`. Vehicles bought through Tesla's B2B program may get the key automatically.
7. Run the vehicle-command proxy with the **private** key.
8. Through the proxy, send `POST /api/1/vehicles/fleet_telemetry_config` with hostname = this FQDN and the fields below. Request-body schema: [UNVERIFIED — confirm against the endpoint docs].
9. Wait for `synced: true` on `GET /api/1/vehicles/{vin}/fleet_telemetry_config`. Check `skipped_vehicles` (missing_key, unsupported_firmware, max_configs), and use `fleet_telemetry_errors` to diagnose.

## Fields BNAV will request on the vehicle config

Location, DestinationLocation, DestinationName, MinutesToArrival, MilesToArrival, VehicleSpeed, Gear, GpsState, RouteLine.

- `vehicle_location` is required for Location, DestinationLocation, DestinationName, GpsState and RouteLine.
- The scope for MinutesToArrival, MilesToArrival, VehicleSpeed and Gear is [UNVERIFIED].

Firmware ≥ 2024.26 (proxy path; the nav fields are also marked 2024.26+ in the proto). Intel Atom Model S/X need ≥ 2025.20. Pre-2018 S/X are unsupported. Two vehicles for Gate 2.

## Do not

- Expose the private key, or host it anywhere.
- Publish the status port (8080) to the internet.
- Point vehicles at localhost.
- Set the Tesla billing limit to $0 and then stream. The default limit is $0, and exceeding the limit removes telemetry configs permanently (they are not restored).
- Add Kafka until logger output is proven on a live VIN.
- Trust payloads blindly. The README advises sanitizing data and allow-listing VINs downstream.

## Config notes

- `reliable_ack` in `config.json` is a compatibility no-op. It appears in Tesla's README and example config, but the current server code does not read it (only `reliable_ack_sources` exists). It provides **no** delivery guarantee. See REVIEW.md.

## Privacy

`config.json` enables verbose JSON logging (`json_log_enable: true`, `logger.verbose: true`) with the `logger` dispatcher. That writes VIN and precise location into the Docker logs on the VM, which are kept under the json-file driver's rotation (5 files x 20 MB). Before the pilot, either define a retention period for these logs or reduce logging, in line with the handoff doc's data-minimization section (store only data required to operate the experience; define retention periods, deletion controls, and consent revocation before Tesla review).
