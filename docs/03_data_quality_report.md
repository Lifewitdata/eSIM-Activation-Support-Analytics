# Phase 3 — Data Quality Report

**Assessment date:** delivered alongside Notebook 1 (`01_data_understanding_and_quality.ipynb`)
**Scope:** all 5 source tables — `customers`, `activation_logs`, `network_logs`, `support_tickets`, `error_codes`
**Verdict: FIT FOR ANALYTICAL USE.** No blocking issues found. Two modeling decisions were made as a result of this assessment (see bottom).

## Summary Scorecard

| Check | Result | Status |
|---|---|---|
| Primary key uniqueness (all 4 keyed tables) | 0 duplicate keys | 🟢 PASS |
| Full-row duplicates | 0 across all tables | 🟢 PASS |
| Referential integrity — `activation.customer_id → customers` | 0 orphans (500,000/500,000 valid) | 🟢 PASS |
| Referential integrity — `tickets.activation_id → activation_logs` | 0 orphans (55,424/55,424 valid) | 🟢 PASS |
| Referential integrity — `tickets.customer_id → customers` | 0 orphans | 🟢 PASS |
| Referential integrity — `activation.failure_code → error_codes` | 0 orphans | 🟢 PASS |
| Missing values | Limited to structurally-expected nulls | 🟢 PASS (see below) |
| Business rule: `FAILED` ⇒ `failure_code` populated, `SUCCESS` ⇒ null | 0 violations | 🟢 PASS |
| Business rule: `retry_count > 0` ⇒ `FAILED` | 0 violations (100% consistent) | 🟢 PASS |
| Numeric range validity (signal, latency, CSAT, price, packet loss, etc.) | 0 out-of-range values across all checked fields | 🟢 PASS |
| Category/enum validity | All values match documented domains | 🟢 PASS |
| Timestamp validity | All timestamps fall within the 2025 operating window, no future/invalid dates | 🟢 PASS |
| Outlier scan (IQR method) — latency, signal, duration, packet loss, bandwidth, resolution time | Negligible to zero flagged outliers; all business-plausible | 🟢 PASS |

## Missing Values — Detail

| Table.Column | Missing | % | Root Cause | Action |
|---|---|---|---|---|
| `activation_logs.failure_code` | 341,624 / 500,000 | 68.3% | Structural — only populated when `activation_status = 'FAILED'`. Confirmed the null pattern is 100% consistent with `SUCCESS` rows. | None needed — not an error. Do not impute. |

All other tables/columns: **zero missing values.**

## Business Rule Validation — Detail

1. **Status/failure_code consistency** — verified all 158,376 `FAILED` rows have a non-null `failure_code` and all 341,624 `SUCCESS` rows have a null `failure_code`. Zero violations.
2. **Retry logic** — verified `retry_count > 0` occurs in 158,376 rows, and **100% of those rows are `FAILED`**. This is a critical finding for downstream modeling: **`retry_count` must be excluded from any causal/predictive root-cause analysis** because it is a *consequence* of failure recorded within the same event, not an independent leading indicator. It is retained only as a customer-friction/effort metric.

## Range & Outlier Checks — Detail

| Field | Documented range | Observed range | Outliers (IQR) |
|---|---|---|---|
| `activation.signal_strength` | 0-100 | 10-100 | 0 |
| `activation.latency_ms` | — | 40-500 | negligible |
| `activation.activation_duration_sec` | — | 20-180 | negligible |
| `network.packet_loss_pct` | 0-100% | 0.0-15.0% | negligible |
| `network.bandwidth_mbps` | — | 5.0-300.0 | negligible |
| `tickets.csat_score` | 1-5 | 1-5 | 0 |
| `tickets.resolution_time_hours` | — | 1.0-72.0 | negligible |
| `customers.price_usd` | — | $4.99-$39.99 | 0 negative/zero values |

## Assessment Commentary

This dataset is unusually clean for a "real Holafly export" — no duplicate customer records, no orphaned foreign keys, no impossible values. In a live production pull we would expect to additionally encounter: duplicate customer records from loyalty-program merges, timezone-inconsistent timestamps across regions, inconsistent partner name spellings (e.g. "AT&T" vs "ATT"), and negative/zero prices from promotional codes. The data quality checks in Notebook 1 were built defensively (explicit business-rule tests, not just null/type checks) so this same pipeline is production-ready to catch those issues if/when a noisier data refresh arrives.

## Modeling Decisions Resulting From This Assessment

1. **Exclude `retry_count` as a predictive root-cause feature** in all root-cause / statistical work (Notebook 4) — it is 100% collinear with the outcome variable and would create false confidence in any model.
2. **Join `network_logs` at the `network_partner` / `region` aggregate level**, not row-by-row against `activation_logs` — the two tables have independent sampling grains and no shared row key.
