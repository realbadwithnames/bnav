# Geofence reliability test plan

Status: written plan and blank results template. Real parking-lot runs, measured rates, and the filled Tesla evidence write-up are not in this document.

This describes Black Nibble's proposed BNAV design for review against the supported Tesla developer platform. It does not state or imply Tesla's approval, endorsement, sponsorship, or association (Fleet API Agreement §14.4.3, last updated March 21, 2025, https://digitalassets.tesla.com/tesla-contents/image/upload/Fleet-API-Agreement-EN.pdf).

Tags: **[TBD]** = a value or founder decision this plan does not set. **[UNVERIFIED]** = not settled by a fetched Tesla or Master Plan source. Parameters below are named so later tests can fill them. None of them is a chosen threshold.

Sources for the product rules are the Master Plan (consolidated Sep 27, 2026, with a Sep 28, 2026 change log) and the strategy handoff it merges. "Doc §8" in GitHub issue #4 is handoff §8. "Doc §18" is the handoff's question list, answered in Master Plan §12.

## 1. Purpose

A correct Fleet API connection can still prompt the driver at the wrong moment. Real-world parking-lot testing is part of the product (handoff §8; Master Plan Gate 4). This plan says what to test, how the geofence uses the Gate 2 telemetry fields, and how to record the false-positive rate and the missed-trigger rate. It does not report results.

The pilot city, the merchant, and the payment path are open. Master Plan §11 and the Sep 28 change log label Orlando, a Square merchant, and Square-native payment as decided or awaiting confirmation. These documents treat all three as open proposed defaults until the founder confirms them. Runs happen at the merchant locations the founder confirms. No merchant polygon exists until that choice is made.

## 2. What the logic is deciding

BNAV owns merchant polygons, the intent engine, and the phone prompt. Tesla supplies read-only vehicle context. Phase 1 requests `vehicle_device_data` and `vehicle_location` only. No commands and no in-car UI (Master Plan §4 and Gate 0).

Two stages, from Master Plan §12, plus the loop in Master Plan §4:

1. **Order stage.** Destination is near the merchant and ETA is within prep time, and the driver has already confirmed. Confirmation happens pre-trip or at a stop. The app does not ask the driver to confirm while the vehicle is moving (Master Plan §4 loop table; §12 failure modes).
2. **Check-in stage.** The vehicle is inside the merchant polygon, is parked or slow, and has stayed that way for a dwell time.

If no navigation destination is set, both stages stay quiet unless the user has opted into a "nearby" mode (Master Plan §12). That opt-in is off unless the user turns it on.

BNAV may recommend, transact, and navigate. It does not control pull-over or drive-through maneuvers (handoff §7; Fleet API Agreement §5.6.22).

## 3. Telemetry fields

Gate 2 requests these fields (issue #3; Master Plan Gate 2). Official descriptions are from Tesla's available-data page, fetched for this plan: https://developer.tesla.com/docs/fleet-api/fleet-telemetry/available-data

| Field | Tesla description (available-data) | Role in the geofence |
|---|---|---|
| Location | Latitude and longitude of the vehicle. From firmware 2025.2.6, a minimum delta in meters can be set. | Point compared with the BNAV polygon. Successive samples are the input to dwell. |
| DestinationLocation | Coordinates of the current navigation destination. Invalid if none is set. | Order-stage proximity to the merchant. |
| DestinationName | Name of the active navigation destination. Invalid if none is set. | Supporting label only. String match against the merchant's name is not defined. |
| MinutesToArrival | Minutes until the navigation destination. Invalid if none is set. | Order stage: compare with merchant prep time. |
| MilesToArrival | Miles until the navigation destination. Invalid if none is set. | Logged on every run. No mile gate is set in this plan. |
| VehicleSpeed | Vehicle speed, in miles per hour (Tesla's wording: "The speed of the vehicle is miles per hour."). | Check-in "slow" gate, and the in-motion guard on prompts. |
| Gear | Current gear reported by the drive inverter (`ShiftState`). | Check-in parked alternative. |
| GpsState | Boolean: GPS lock is acquired. | If false, Location is not a trigger. |
| RouteLine | Base64-encoded polyline of the active route, Google polyline algorithm, precision 6. | Logged so a later pass can compare the route with the entrance the driver used. No corridor width is set. |

`vehicle_location` is required for Location, DestinationLocation, DestinationName, RouteLine, and GpsState (https://developer.tesla.com/docs/fleet-api/fleet-telemetry). The scope that gates MinutesToArrival, MilesToArrival, VehicleSpeed, and Gear is **[UNVERIFIED]** (Master Plan §14). A run missing any of the nine fields is void. It is not scored as a geofence miss.

A datum may arrive as `invalid: true` when the vehicle cannot measure it (available-data page). DestinationLocation, DestinationName, MinutesToArrival, and MilesToArrival are Invalid when no destination is set.

The parked gear in Tesla's proto is `ShiftStateP` (`ShiftStateUnknown`, `ShiftStateInvalid`, `ShiftStateP`, `ShiftStateR`, `ShiftStateN`, `ShiftStateD`, `ShiftStateSNA`): https://github.com/teslamotors/fleet-telemetry/blob/main/protos/vehicle_data.proto. Master Plan §12 writes this as "Gear = P". The test logs the token the receiver actually emits and locks the comparison to that token before scored runs. Fleet Telemetry client 1.1.0 removed `prefer_typed` and says all data is returned typed (https://developer.tesla.com/docs/fleet-api/fleet-telemetry). This plan has not seen a live payload.

Other behavior that changes timing, all from the Fleet Telemetry page:

- The vehicle gathers fields in 500 ms buckets. A field is sent only after its `interval_seconds` has elapsed and the value has changed.
- On loss of connectivity the vehicle buffers 5,000 messages, at least 2,500 seconds, and delivers them on reconnect.
- A share with `granular_access.hide_private = true` cannot stream Location, DestinationLocation, DestinationName, RouteLine, or GpsState. A config that includes them is rejected with 403 "location access not granted". Tesla's list also names OriginLocation and GpsHeading, which this plan does not request. VehicleSpeed and Gear are not in that list.

`interval_seconds` and Location `minimum_delta` are chosen when the vehicle config is sent. They are **[TBD]**. Because a field is sent only after the interval and a change, a parked car may stop emitting Location. Whether silence counts as continued dwell is parameter `dwell_silence_counts`, **[TBD]**. Testers record the gap between Location samples either way.

BNAV does not request LocatedAtHome, LocatedAtWork, LocatedAtFavorite, or DriverSeatOccupied. Those fields exist on the available-data page. They are outside the Gate 2 list. The privacy summary bars inferring identities or family relationships.

## 4. Parameters

Every numeric threshold is unset. Gate 4 says to tune the ETA threshold, the speed/gear gate, and dwell in the field, and to hold false-positive and missed-trigger rates at or below pre-set bars over a pre-set number of runs. The bars and the run count are **[TBD]** (Master Plan Gate 4 and §11).

| Parameter | Used for | Value |
|---|---|---|
| `dest_radius_m` | Order stage: DestinationLocation within this distance of the merchant point | **[TBD]** |
| `prep_time` | Order stage: MinutesToArrival at or under merchant prep time | **[TBD]** (source is the merchant's prep time, not Tesla) |
| `speed_gate_mph` | Check-in: VehicleSpeed below this, if not parked | **[TBD]** |
| `dwell_s` | Check-in: time the parked-or-slow condition holds inside the polygon | **[TBD]** |
| `dwell_silence_counts` | Whether a gap in Location samples still counts as dwell | **[TBD]** |
| `motion_cutoff_mph` | Speed at or above which a prompt must not be shown | **[TBD]** |
| `gear_parked_token` | Gear value treated as parked | **[TBD]** until a Gate 2 vehicle shows the token |
| `cancel_window` | Time the driver can cancel after the order stage and before prep | **[TBD]** (Master Plan §12) |
| `miles_gate` | Optional MilesToArrival cross-check | **[TBD]**; unused unless set |
| `route_corridor` | Optional RouteLine comparison with the entrance | **[TBD]**; unused unless set |
| `fp_bar` | Maximum false-positive rate | **[TBD]** |
| `miss_bar` | Maximum missed-trigger rate | **[TBD]** |
| `run_count` | Scored runs required before Gate 4 exit | **[TBD]** |
| `interval_seconds` | Per-field telemetry interval | **[TBD]** at config time |
| `minimum_delta_m` | Location minimum delta, if the firmware supports it | **[TBD]** |

`motion_cutoff_mph` and `speed_gate_mph` may later be set equal. This plan does not decide that.

Merchant prep time, if the founder confirms Square, can come from the Orders API `prep_time_duration` field (https://developer.squareup.com/docs/orders-api/fulfillments). Until that decision, prep time is whatever the confirmed merchant provides.

## 5. Pass, fail, and void

Scoring matches Master Plan §10, which the KPI document uses for the same rates.

- A **trigger** is an order-stage prompt the app shows, or a check-in the engine emits.
- An **incorrect trigger** is a trigger the script did not expect (wrong merchant, drive-by, adjacent lot, prompt while moving, or check-in before the script's dwell condition). Until `motion_cutoff_mph` is set, mark a prompt-while-moving row provisional and record the speed.
- A **scripted arrival** is a run in which the tester reaches the fulfillment point and stops, as the script requires.
- A **missed arrival** is a scripted arrival whose expected stage never fired before the tester ends the run at that point. No extra timer is set.
- An **actual arrival** is a scripted arrival, whether or not a trigger fired.

Rates, computed only when the denominator is greater than zero:

- False-positive rate = incorrect triggers ÷ triggers
- Missed-trigger rate = missed arrivals ÷ actual arrivals

A **void** run is not in either rate. Void means a required field was missing or Invalid for a reason other than "no destination" on a no-destination script, GpsState was false when the script needed lock, the stream was down, the config was rejected, or the tester could not complete the script safely. Voids are counted in the template so an outage is not reported as a perfect score.

Order-stage and check-in-stage counts are kept separately and then added for the combined rate. The combined rate is the KPI. The split is there so a later evidence pack can see which stage failed.

## 6. Preconditions

Do not start scored runs until all of the following are true:

- The vehicle is streaming the nine fields and the telemetry config reports synced (issue #3; Master Plan Gate 2). Firmware is at least 2024.26. Intel Atom Model S/X need at least 2025.20 (https://developer.tesla.com/docs/fleet-api/fleet-telemetry).
- The authorizing account is not a `hide_private` share. Those shares cannot stream Location, DestinationLocation, DestinationName, RouteLine, or GpsState (see §3).
- The Tesla account has a payment method and a billing limit above zero. Exceeding the limit suspends API usage and removes Fleet Telemetry streaming configurations. Tesla states those configurations will not be restored (https://developer.tesla.com/docs/fleet-api/billing-and-limits).
- The merchant polygon and the fulfillment point are drawn for the confirmed merchant. The polygon is BNAV data, not a Tesla field (Master Plan §4).
- The driver and the fleet operator have completed the consent in `docs/privacy-data-retention.md`, including express opt-in before precise geolocation (Fleet API Agreement §9.3.5).
- Testers do not read or tap a prompt while the vehicle is moving. If a case needs a GPS fault that cannot be produced without a driving hazard, mark it blocked, not passed.

## 7. Cases

Each case records the nine fields, whether the point was inside the polygon, the dwell the engine computed, the inter-sample gap, and the classification in §5. Lot size, entrance count, and observed GPS spread are written in the notes as measurements. They are not pass thresholds.

### 7.1 GPS drift

Park inside the polygon with GpsState true and Gear parked. Record the spread of Location samples in meters. Repeat with a safe stop whose samples fall on both sides of the polygon edge, if the lot has such a stop. Repeat a no-lock case only when GpsState is false without creating a hazard: expected result is no Location trigger, and the fallback in §7.7. If `minimum_delta_m` is set, note it, because small movement will not be emitted.

### 7.2 Merchant entrance geometry

Before the session, record how many vehicle entrances the lot has and where the fulfillment point is relative to the navigation pin. Run one arrival per entrance the merchant actually uses. DestinationLocation may sit on the building while the fulfillment point is a window or a curb stall. The script's expected check-in is the fulfillment point, not the pin. Log RouteLine and DestinationName. Do not score a name mismatch as a fail unless `route_corridor` or a name rule is later set.

### 7.3 Parking-lot size

Record a plain description of the lot (small curb, single aisle, multi-aisle). Two scripted arrivals:

- Stop at the fulfillment point.
- Stop inside the polygon but far from the fulfillment point, if the lot has that distance.

A large polygon can check in early. That row is an incorrect trigger if the script required the fulfillment point. One field response is to redraw the polygon. This plan does not set a maximum lot size.

### 7.4 Trigger radius and timing

With a destination set to the merchant, approach until the order stage fires. Record MinutesToArrival, MilesToArrival, the distance from DestinationLocation to the merchant point, VehicleSpeed, and Gear at the prompt. The prompt is expected only when DestinationLocation is within `dest_radius_m`, MinutesToArrival is at or under `prep_time`, the driver already confirmed while stopped, and speed is under `motion_cutoff_mph`.

Then enter the polygon and hold the parked or slow condition. The check-in is expected only after `dwell_s`. Record timestamps of the samples and of the prompt so latency is visible. The 500 ms batch and `interval_seconds` limit how tight that latency can be (Fleet Telemetry system behavior).

### 7.5 False positives

Expected result on each of these is no trigger:

- Drive past on the adjacent road without entering.
- Enter an adjacent lot and park there.
- Pass the merchant with a navigation destination set to a different place.
- Pass or enter with no destination and without the nearby opt-in.
- Move through the lot above `motion_cutoff_mph` without a stop that meets dwell.

A trigger on any of these is an incorrect trigger. Nearby opt-in, if the tester enables it, is a separate script, not the default.

### 7.6 Missed triggers

Expected result is a trigger of the stage under test. A completed scripted arrival without that trigger is a miss:

- Destination set, lock held, stop at the fulfillment point long enough for `dwell_s`.
- Creep through the lot so speed stays above `speed_gate_mph` and Gear never reaches the parked token. This may be a miss of the check-in stage. Record it that way; do not lower the gate in the field to force a pass.
- Polygon drawn so the entrance the driver used is outside it. That is a miss caused by geometry. The note says so.
- No destination and no nearby opt-in. The expected result is suppression, not a miss. Do not count it as a missed arrival.

### 7.7 Early and late events

**Early.** The order stage can become true while the vehicle is still on the way, because it uses destination proximity and ETA rather than the polygon. The driver must already have confirmed while stopped. After the order stage, the driver has `cancel_window` before prep (Master Plan §12). The check-in stage does not fire on the order-stage condition alone. A detour after the order stage is logged as its own row: the order may stand or be canceled; the check-in waits for the polygon rule.

**Late.** If the link drops, the vehicle can deliver buffered messages after reconnect (5,000 messages, at least 2,500 seconds). A check-in that arrives only after reconnect is a late event. Score it as a miss of the on-time check-in, and record the fallback that the tester used. Do not drop it from the log.

Fallbacks, from Master Plan Gate 4 and §12:

- Manual "I'm here" in the BNAV app.
- Phone GPS, only with the same express geolocation opt-in as vehicle location (Fleet API Agreement §9.3.5; see the privacy summary).
- No automatic trigger while GpsState is false or the stream is down.

Merchant rejection, food not ready, and refunds are fulfillment cases. They are out of this matrix except as a note if they interrupt a run (Master Plan §12).

## 8. Results template

Fill this after real runs. Leave rates blank when the denominator is zero. The completed tables are the geofence section of the Tesla evidence package. Do not put VINs in this table; use a vehicle alias. Raw location stays under the retention rule in the privacy summary.

### 8.1 Run log

| Run | Date | Vehicle alias | Merchant / lot | Case (§7) | GpsState | Gear token | Speed (mph) | MinutesToArrival | MilesToArrival | Destination set | Inside polygon | Dwell (s) | Sample gap (s) | Expected | Actual | Class (TP / FP / miss / TN / void) | Notes (spread, entrance, late/early) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | | | | | | |

### 8.2 Rates

| Stage | Triggers | Incorrect triggers | False-positive rate | Actual arrivals | Missed arrivals | Missed-trigger rate | Voids |
|---|---|---|---|---|---|---|---|
| Order | | | | | | | |
| Check-in | | | | | | | |
| Combined (KPI) | | | | | | | |

False-positive rate = incorrect triggers ÷ triggers. Missed-trigger rate = missed arrivals ÷ actual arrivals.

| Bar | Value | Result against the bar |
|---|---|---|
| `fp_bar` | **[TBD]** | |
| `miss_bar` | **[TBD]** | |
| `run_count` met | **[TBD]** | |

Observed GPS spread, lot description, and entrance count stay in the run notes. They are measurements, not targets.

## 9. Not done here

- No scored runs at a pilot merchant.
- No measured false-positive or missed-trigger rate.
- No evidence-package narrative beyond this empty template.
- No change to the telemetry receiver. Logging of VIN and precise location is covered by the privacy summary, not by this plan.

## 10. Sources

- Master Plan §4 (loop, ownership, field mapping), Gate 4, §10 (rate formulas), §11 (open defaults and **[TBD]** bars), §12 (stage rules and fallbacks), §14 (unverified scope).
- Handoff §7 (no vehicle control), §8 (test topics), §12 item "Geofence test plan/results". Nearby suppression is Master Plan §12.
- Issue #3 field list.
- https://developer.tesla.com/docs/fleet-api/fleet-telemetry/available-data
- https://developer.tesla.com/docs/fleet-api/fleet-telemetry
- https://developer.tesla.com/docs/fleet-api/billing-and-limits
- https://github.com/teslamotors/fleet-telemetry/blob/main/protos/vehicle_data.proto
- Fleet API Agreement §5.6.22, §9.3.5, §14.4.3: https://digitalassets.tesla.com/tesla-contents/image/upload/Fleet-API-Agreement-EN.pdf
- Square `prep_time_duration`, only if that merchant path is confirmed: https://developer.squareup.com/docs/orders-api/fulfillments
