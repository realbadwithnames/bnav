# Pilot KPI definitions

Status: definitions, formulas, data sources, and the tracking method. Nothing here is instrumented yet. Numeric targets are **[TBD]** unless the Master Plan states one with a source. It does not. Master Plan §9's illustrative economics are omitted.

This is Black Nibble's proposed measurement set for a later evidence package. It does not state or imply Tesla's approval, endorsement, sponsorship, or association (Fleet API Agreement §14.4.3, https://digitalassets.tesla.com/tesla-contents/image/upload/Fleet-API-Agreement-EN.pdf, last updated March 21, 2025).

Tags: **[TBD]** = not set. **[UNVERIFIED]** = no fetched source settles it.

The definitions quote Master Plan §10, which restates handoff §13. Pass bars are locked before pilot Day 1, using baseline measurements, and the numbers are **[TBD]** (Master Plan Gate 4, Gate 5, §11, §12). The pilot window itself is **[TBD]**. Master Plan §11 recommends Weeks 10–16 and notes that 90-day retention needs a longer tail. That recommendation is not a decision.

Pilot city, merchant platform, and payment path are open proposed defaults. Master Plan §11 labels Orlando, a Square merchant, and Square-native payment as decided or awaiting confirmation. This document does not treat them as decided. Where a formula needs the merchant system or the processor, it names "the merchant system the founder confirms" and "the processor the founder confirms".

The KPI store keeps derived events and order totals. It does not keep raw location traces. Retention of those rows follows `docs/privacy-data-retention.md`.

## 1. Shared terms

These terms keep the §10 formulas from colliding. Where §10 does not define a word, the gap is marked **[TBD]** and the tracking row still stores the inputs.

| Term | Working meaning | Status |
|---|---|---|
| Period | The pilot window locked before Day 1 | **[TBD]** |
| Trigger shown | An order-stage prompt the BNAV app displayed | Matches "eligible triggers shown" in §10. Whether an automatic check-in also counts is **[TBD]**; check-ins are already inside the geofence rates. |
| Confirmed order | A driver confirmation, made while stopped, that submits an order or check-in | Numerator of trigger-to-confirm |
| Order sent | A submission BNAV made to the merchant system | Denominator of the merchant error rate |
| Order placed | A sent order the merchant system created | Working split so "placed" and "sent" are not the same word. Confirm before Day 1 **[TBD]** |
| Order completed | Merchant fulfillment state reached completed, with no manual fix flagged | "Without intervention" has no further definition in §10. The flag rule is **[TBD]** |
| Active driver | Used only by repeat-order rate. §10 does not define it | **[TBD]**. Store driver id, order count, and whether that driver had a trip, so either reading can be computed |
| Trip | A stretch in which the vehicle streamed telemetry | Session boundary **[TBD]**. Connectivity events exist (https://developer.tesla.com/docs/fleet-api/fleet-telemetry) and are not yet the boundary |
| Order total | The total on the merchant order | Whether tax, tip, or fees sit inside that total is **[TBD]** with the payment path |
| BNAV fee | Amount Black Nibble charges on an order | Open. Master Plan §11: the per-order fee amount is still open |
| Vehicle alias | Id used in the KPI store | The VIN stays with the vehicle-identity record in the privacy summary, not in this rollup |

Geofence classes (true positive, false positive, miss, true negative, void) are defined in `docs/geofence-test-plan.md` §5. The rates below use that scoring, including the rule that void runs stay out of both denominators.

## 2. Trigger-to-confirm conversion rate

**Definition (Master Plan §10).** Confirmed orders ÷ eligible triggers shown.

**Formula.** confirmed orders in the period ÷ triggers shown in the period. If the denominator is zero, do not compute a rate; report the counts.

**Data source.** BNAV app events: `trigger_shown`, `order_confirmed`. The app is the confirm surface (Master Plan §4).

**Tracking.** One row per prompt and one row per confirmation, joined by prompt id. Weekly review during the pilot (Master Plan Gate 5). Not built.

**Target.** **[TBD]** before Day 1. §12 lists conversion as a candidate bar for any later native-UI request and sets no number.

## 3. Repeat-order rate

**Definition (Master Plan §10).** Share of active drivers with 2+ orders in the period.

**Formula.** drivers with at least two orders in the period ÷ active drivers in the period.

**Data source.** BNAV order records, counted per driver id. "Active driver" is **[TBD]** (§1).

**Tracking.** Store driver id, order id, and order time. Compute the ratio only after the active-driver rule is locked. Weekly review. Not built.

**Target.** **[TBD]**.

## 4. Orders per active vehicle

**Definition (Master Plan §10).** Orders ÷ vehicles with at least one trip.

**Formula.** orders in the period ÷ vehicles with at least one trip in the period. "Orders" here follows order placed (§1), **[TBD]** to confirm.

**Data source.** BNAV order records for the numerator. Derived trip events for the denominator (a trip is telemetry presence, not a raw trace).

**Tracking.** Store vehicle alias, trip id, and order id. Session boundaries wait on **[TBD]** in §1. Weekly review. Not built.

**Target.** **[TBD]**. Gate 2's exit is streaming on at least two vehicles (Master Plan Gate 2). That is not a pilot fleet-size target. No documented fleet cap was found **[UNVERIFIED]** (Master Plan §11, §14).

## 5. Average order value

**Definition (Master Plan §10).** GMV ÷ orders.

**Formula.** GMV in the period ÷ orders in the GMV sum. Both use order placed and order total from §1.

**Data source.** Merchant order totals as recorded when the order is created. The merchant system is the founder-confirmed platform.

**Tracking.** Store order id and order total at creation. Do not recompute GMV from a price assumption. Weekly review. Not built.

**Target.** **[TBD]**. No average-order target is stated outside Master Plan §9, which this set does not use.

## 6. Fulfillment success rate

**Definition (Master Plan §10).** Orders completed without intervention ÷ orders placed.

**Formula.** orders completed without a manual-fix flag ÷ orders placed.

**Data source.** Fulfillment state from the merchant system. The loop's fulfill step reads that state (Master Plan §4). If the founder confirms Square, fulfillment state is the Orders API fulfillment (https://developer.squareup.com/docs/orders-api/fulfillments). Staff alerting on a pickup-note edit is **[UNVERIFIED]** (Master Plan §14).

**Tracking.** Store merchant order id, fulfillment state, and a manual-fix flag. The flag rule is **[TBD]** (§1). Weekly review, plus the merchant feedback loop at Gate 5. Not built.

**Target.** **[TBD]**. Listed in §12 as a candidate bar, with no number.

## 7. Merchant acceptance / error rate

**Definition (Master Plan §10).** Rejected, failed, or manually fixed orders ÷ orders sent.

**Formula.** (rejected + failed + manually fixed) ÷ orders sent. An order can appear in the manually-fixed count and also in fulfillment success's complement. The two KPIs use different denominators (sent vs placed) and both stay.

**Data source.** BNAV's submission log (sent, rejected, failed) and the merchant system's error or the manual-fix flag.

**Tracking.** One row per submission with a terminal status: accepted, rejected, failed, or manually fixed. Weekly review. Not built.

**Target.** **[TBD]**.

## 8. Geofence false-positive and missed-trigger rate

**Definition (Master Plan §10).** Incorrect triggers ÷ triggers; missed arrivals ÷ actual arrivals.

**Formulas.**

- False-positive rate = incorrect triggers ÷ triggers
- Missed-trigger rate = missed arrivals ÷ actual arrivals

Classes, voids, and the order-stage versus check-in split are in `docs/geofence-test-plan.md` §5 and §8.2. The combined row is this KPI.

**Data source.** The geofence run log during Gate 4, then the same classification on pilot arrivals. Inputs are the Gate 2 fields named in that plan. Scope for MinutesToArrival, MilesToArrival, VehicleSpeed, and Gear is **[UNVERIFIED]** (Master Plan §14).

**Tracking.** The results template in the geofence plan is the Gate 4 record. During the pilot, each automatic trigger and each scripted or driver-reported arrival gets the same class. Weekly review. The template is not filled. Classification in the running app is not built.

**Target.** `fp_bar` and `miss_bar` are **[TBD]** (Master Plan Gate 4). §12 names false-trigger rate as a candidate bar for a later native-UI request and sets no number.

## 9. Time saved from trigger to pickup

**Definition (Master Plan §10).** Median arrival → handoff versus a baseline measurement.

**Formula.** median (handoff time − arrival time) for completed orders, minus the baseline median for the same merchant. Report minutes. If either median has no observations, do not publish a delta.

**Data source.** Arrival time is the check-in timestamp (automatic, manual "I'm here", or phone-GPS fallback) from the geofence plan §7.7. Handoff time is the merchant fulfillment-completed timestamp. The baseline method is **[TBD]**; §10 requires a measurement and does not describe one.

**Tracking.** Store arrival time, handoff time, and a baseline flag on the comparison runs. Weekly review once both series exist. Not built.

**Target.** **[TBD]**. No saved-time target is stated in the Master Plan.

## 10. 30-day and 90-day retention

**Definition (Master Plan §10).** Week-1 actives ordering again in days 25–30 / days 85–90.

**Formulas.**

- 30-day retention = week-1 actives who order again on days 25–30 ÷ week-1 actives
- 90-day retention = week-1 actives who order again on days 85–90 ÷ week-1 actives

"Week-1 actives" and the clock (first order, account start, or pilot Day 1) are not defined in §10. Both are **[TBD]** before Day 1. Days are counted on that clock once it is chosen.

**Data source.** BNAV order history keyed by driver id. Order history stays inside BNAV, not in Tesla vehicle context (Master Plan §5).

**Tracking.** Store driver id and order timestamps. A 30-day figure needs at least 30 days after the cohort's week 1. A 90-day figure needs the longer tail Master Plan §11 already flags. Weekly review can show the cohort filling in; the rate itself waits for the window. Not built.

**Target.** **[TBD]**. §12 lists 30-day retention as a candidate bar and sets no number.

## 11. Gross merchandise volume (GMV)

**Definition (Master Plan §10).** Order totals.

**Formula.** Sum of order totals for orders placed in the period (§1).

**Data source.** Merchant order totals. Not a forecast and not Master Plan §9.

**Tracking.** Sum the order-total field already stored for average order value. Weekly review. Not built.

**Target.** **[TBD]**. No GMV target is used here.

## 12. BNAV net platform revenue

**Definition (Master Plan §10).** BNAV fees minus processing and Tesla API costs.

**Formula.** Sum of BNAV fees on orders in the period − processing fees on those orders − Tesla API charges for the period.

Until the per-order fee is set, the fee term is **[TBD]** and the KPI is not computed (Master Plan §11). Processing fees are the amount the confirmed processor bills, not a rate typed in from a pricing page. Tesla API cost is the amount on Tesla's bill for the account, from Tesla billing (https://developer.tesla.com/docs/fleet-api/billing-and-limits). Published US prices live on https://developer.tesla.com/ and are a way to read that bill, not a substitute for it.

**Data source.** BNAV fee ledger (empty until the fee is decided), the processor's fee report, and Tesla's billing record.

**Tracking.** Import those three figures once per review week. Gate 5 includes a cost review. Not built.

**Target.** **[TBD]**. No revenue target is stated outside Master Plan §9, which is omitted.

## 13. Tracking checklist before Day 1

Gate 5 entry requires the pass bars to be written down before Day 1, and driver consent collected (Master Plan Gate 5). This document is the definition set. Still open:

- Instrument the events named above.
- Lock every **[TBD]** in §1, plus `fp_bar`, `miss_bar`, and the other bars.
- Confirm city, merchant system, payment path, and the fee amount.
- Keep the KPI store free of raw location, under the privacy summary.

## 14. Sources

- Master Plan §4, §5, §10, Gate 4, Gate 5, §11, §12, §14.
- Handoff §13 (the KPI list) and §12 item "Pilot KPI definitions".
- Geofence classes: `docs/geofence-test-plan.md`.
- https://developer.tesla.com/docs/fleet-api/fleet-telemetry
- https://developer.tesla.com/docs/fleet-api/billing-and-limits
- https://developer.tesla.com/
- Fleet API Agreement §14.4.3: https://digitalassets.tesla.com/tesla-contents/image/upload/Fleet-API-Agreement-EN.pdf
- Square fulfillments, only if that path is confirmed: https://developer.squareup.com/docs/orders-api/fulfillments
