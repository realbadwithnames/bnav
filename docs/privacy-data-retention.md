# Privacy and data-retention summary

One-page Tesla review copy for the proposed BNAV application. The public privacy policy is still a Gate 1 item (Master Plan Gate 1; Fleet API Agreement §5.4, §9.3.3).

BNAV is Black Nibble's application. This page does not state or imply Tesla's approval, endorsement, sponsorship, or association (§14.4.3). The application name does not use "Tesla" or a Tesla product name (§7). Agreement: Fleet API Agreement, last updated March 21, 2025, https://digitalassets.tesla.com/tesla-contents/image/upload/Fleet-API-Agreement-EN.pdf

Phase 1 is read-only: `vehicle_device_data` and `vehicle_location`. No commands, no Tesla payment access, no in-car UI (Master Plan §4, Gate 0). BNAV does not control vehicle maneuvers (handoff §7; §5.6.22). **[TBD]** means the founder has not set the duration. The 30-day rule is the Agreement's deletion deadline after a trigger. Pilot city, merchant platform, and payment path are open proposed defaults (Master Plan §11 labels them more firmly; this page treats them as open).

## Data stored

Only what the loop needs (handoff §7; Master Plan §5). Gate 2 fields (issue #3): Location, DestinationLocation, DestinationName, MinutesToArrival, MilesToArrival, VehicleSpeed, Gear, GpsState, RouteLine. "Precise Geolocation" means a location within a circle of radius 1,850 feet.

| Category (all in BNAV unless noted) | Retention |
|---|---|
| VIN and vehicle list, to bind a consented vehicle | While in the pilot and consent stands; then **[TBD]** |
| Raw location, destination, route, ETA, distance, GpsState | Shortest geofence-debug window **[TBD]**. Master Plan §11 proposal ≤24–72 h is **[TBD]** |
| VehicleSpeed, Gear | Same raw window **[TBD]** |
| Derived trip/geofence events, no raw trace | Pilot plus analysis, both **[TBD]** (Master Plan §5) |
| User-created profile. Allergy only if the user enters it | Until the user deletes it. Period **[TBD]** |
| Merchant-supplied allergen/ingredient data | Cache, if any, **[TBD]** |
| Orders and order history (not written to Tesla vehicle context) | As law and the processor require **[TBD]** (Master Plan §5) |
| Processor tokens. Card numbers stay off BNAV servers (Master Plan §4, §5) | Processor lifecycle **[TBD]** |
| Consent record: categories, time, revocation | **[TBD]** |
| Receiver logs (below), on the telemetry VM | Same raw window **[TBD]** |
| KPI rollups (`docs/pilot-kpis.md`); no raw location | **[TBD]** |

Not requested, though listed at https://developer.tesla.com/docs/fleet-api/fleet-telemetry/available-data: LocatedAtHome, LocatedAtWork, LocatedAtFavorite, DriverSeatOccupied.

## Consent, revocation, and inference

The user creates the profile and consents explicitly (handoff §7). Before Precise Geolocation is collected or stored, each affected user and the fleet operator give express opt-in, and the BNAV phone app shows a conspicuous indicator while location is determined (§9.3.5). A location-sharing icon is documented for `vehicle_data` on firmware 2023.38+ (https://developer.tesla.com/docs/fleet-api/endpoints/vehicle-endpoints). Whether it appears for telemetry streaming is **[UNVERIFIED]** (Master Plan §14). Each category has its own opt-in; a wider use needs a new one (§9.3.7). Consent is explicit, prior, specific, informed, and freely given, in writing (§9.3.2), and covers Addendum 1, including https://www.tesla.com/legal/privacy. Screen copy is **[TBD]** (Master Plan week 1). The user or fleet operator can review and revoke (§9.3.8). Revocation stops access (§5.6.18).

BNAV does not infer allergies, identities, family relationships, or sensitive preferences from occupants. Allergies are user-declared; allergen data comes from the merchant (handoff §7; Master Plan §5). §9.3.6 bars processing Tesla Personal Data that is Sensitive Information, and bars inferring it: personal data treated as sensitive under applicable law, including health (including pregnancy), political affiliations or beliefs, race or ethnic origin, religious or philosophical affiliation or beliefs, sex or sexual orientation, trade union membership, age, disability, or genetic information. Order history and preferences stay in BNAV, not in Tesla vehicle context.

## Deletion, telemetry logs, security

Update or delete Tesla Personal Data within 30 days after it is no longer necessary for the stated and approved functionality, the application stops, Tesla asks, the individual asks, or the law requires it (§9.3.10.1–§9.3.10.5). The **[TBD]** windows are that necessary period.

Gate 2 verbose JSON logging writes VIN and precise location to Docker logs, 5 files × 20 MB (`telemetry/SETUP.md`, Privacy). That cap is size, not a retention period. Logs follow the raw window **[TBD]** and are not kept longer than the raw trace. A separate pull request is reducing VIN and precise-location logging in the receiver. This page is the policy, not that implementation. Until it lands, delete these logs on the raw window before the pilot relies on them.

§9.4.2 requires encryption in transit and at rest. The receiver terminates mTLS (`telemetry/SETUP.md`). At-rest protection for stored categories is **[TBD]**. Report unauthorized credential or API access as soon as possible and no later than 48 hours (§5.5). Report a suspected breach of Tesla Personal Data immediately (§9.3.9).

Sources: handoff §7; Master Plan §4, §5, Gates 0–1, §11, §14; issue #3; `telemetry/SETUP.md`. Agreement §§5.4, 5.5, 5.6.18, 5.6.22, 7, 9.3.2–9.3.3, 9.3.5–9.3.10, 9.4.2, 14.4.3.
