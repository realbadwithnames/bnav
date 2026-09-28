# bnav

BNAV (Black Nibble Arrival Vector) is a vehicle-native arrival-commerce layer: intent → confirm → done.

Phase 1 reads authorized vehicle context only (Fleet API scopes `vehicle_device_data` and `vehicle_location`). This repo does not send vehicle commands.

Fleet Telemetry receiver (Tesla `fleet-telemetry` on a small cloud VM): [telemetry/SETUP.md](telemetry/SETUP.md).

- Image pin, VM runbook, and localhost-only status port: `telemetry/docker-compose.yml`
- Application key pair: `telemetry/scripts/generate-keypair.sh`
- `fleet_telemetry_config` body (placeholders only): `telemetry/fleet_telemetry_config.template.json`
- Log retention for the receiver: `telemetry/SETUP.md` (Privacy)
