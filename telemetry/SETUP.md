# BNAV Fleet Telemetry — cloud box

Not the Windows laptop. Vehicles will not stream to a sleeping Victus.

Tesla ships `tesla/fleet-telemetry` on Docker Hub. Official install path is a public FQDN, TLS terminated on this process, then a dispatcher. For Gate 2 we log JSON to stdout. Kafka comes when two cars are boring.

## What Docker is for

| Job | Where |
|---|---|
| QAI garage API + Postgres | Your laptop, if you want that lab |
| Tesla Fleet Telemetry receiver | A small always-on VPS you control (1 vCPU, 2 GB, public IP, ports 443 + 8080) |

Do not run this image on the laptop.

## VM steps

1. Buy a cheap cloud VM. Point `telemetry.<your-domain>` A-record at it.
2. Install Docker Engine on the VM (not Docker Desktop).
3. Copy this folder to the VM.
4. Put a real cert on the FQDN:
   - `certs/tls.crt` (full chain)
   - `certs/tls.key`
5. `docker compose up -d`
6. From a laptop: Tesla's `check_server_cert.sh` against hostname + port 443 + CA chain.

Status port is 8080 on localhost of the VM.

## After Gate 1 (app registered)

```
openssl ecparam -name prime256v1 -genkey -noout -out private-key.pem
openssl ec -in private-key.pem -pubout -out public-key.pem
```

Host `public-key.pem` at:

`https://<app-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem`

That domain is the **application** domain from developer.tesla.com. It can be the same host or a different one from `telemetry.<domain>`. Both need working TLS.

Then: partner token → register endpoint (NA) → pair virtual key (`tesla.com/_ak/<domain>`) → vehicle-command proxy with the **private** key → `POST fleet_telemetry_config` with hostname = this FQDN → wait until `synced: true`.

## Fields BNAV will request on the vehicle config

Location, DestinationLocation, DestinationName, MinutesToArrival, MilesToArrival, VehicleSpeed, Gear, GpsState, RouteLine.

Firmware ≥ 2024.26. Two vehicles for Gate 2.

## Do not

- Expose the private key.
- Point vehicles at localhost.
- Set Tesla billing limit to $0 and then stream. Exceeding the limit removes configs permanently.
- Add Kafka until logger output is proven on a live VIN.

## Privacy

`config.json` enables verbose JSON logging (`json_log_enable: true`, `logger.verbose: true`) with the `logger` dispatcher. That writes VIN and precise location into the Docker logs on the VM, which are kept under the json-file driver's rotation (5 files x 20 MB). Before the pilot, either define a retention period for these logs or reduce logging, in line with the handoff doc's data-minimization section (store only data required to operate the experience; define retention periods, deletion controls, and consent revocation before Tesla review).
