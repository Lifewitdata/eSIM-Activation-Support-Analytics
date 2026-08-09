# Phase 2 — Data Dictionary

Full ER diagram and relationship validation live in `notebooks/01_data_understanding_and_quality.ipynb`. This document is the field-by-field reference.

---

## 1. `customers.csv` — Dimension | Grain: 1 row per customer | 100,000 rows | Owner: Product & Growth

| Column | Type | Description | Notes |
|---|---|---|---|
| `customer_id` | string (PK) | Unique customer identifier | No duplicates, 100% unique |
| `customer_name` | string | Full name | PII — mask/hash before any external sharing |
| `email` | string | Contact email | PII |
| `home_country` | string | Customer's country of residence | |
| `destination` | string | Destination country for the (most recent) purchased plan | May not match `activation_logs.destination` for a specific attempt — see grain note in Notebook 1 |
| `region` | string | Destination region (5 values: Asia, Europe, North America, Oceania, South America) | |
| `purchase_date` | datetime | When the plan was purchased | Range: 2025-01-01 to 2025-12-30 |
| `plan_type` | string | Data plan tier: 1 GB, 3 GB, 5 GB, 10 GB, Unlimited | |
| `validity_days` | int | Plan validity window in days | Range 7-30 |
| `price_usd` | float | Plan price in USD | Range $4.99-$39.99; used as revenue proxy |
| `device_os` | string | Android / iOS | |
| `os_version` | int | OS major version at time of purchase | |
| `device_model` | string | Device model | |
| `customer_segment` | string | New / Returning / Business | |
| `language` | string | Preferred language | |

## 2. `activation_logs.csv` — Fact | Grain: 1 row per activation attempt | 500,000 rows | Owner: Engineering

| Column | Type | Description | Notes |
|---|---|---|---|
| `activation_id` | string (PK) | Unique activation attempt identifier | |
| `order_id` | string | Order identifier | Unique per row — 1:1 with activation_id in this dataset |
| `customer_id` | string (FK → customers) | Links to customer | 100% referential integrity |
| `activation_time` | datetime | Timestamp of the attempt | Range: 2025-01-01 to 2025-12-30 |
| `destination` | string | Destination country **for this specific attempt** | Authoritative over `customers.destination` for activation analysis |
| `region` | string | Destination region | |
| `network_partner` | string | Telecom partner used: Telefonica, T-Mobile, Orange, AT&T, Airtel, Vodafone | |
| `device_os` | string | Android / iOS | |
| `os_version` | int | OS version at time of attempt | |
| `device_model` | string | Device model | |
| `signal_strength` | int | Signal strength, 10-100 | |
| `latency_ms` | int | Network latency in ms, 40-500 | |
| `activation_duration_sec` | int | How long the attempt took, 20-180s | Near-identical for success/failure — see Notebook 2 Q12 |
| `activation_status` | string | SUCCESS / FAILED | Target variable for most analysis |
| `failure_code` | string (FK → error_codes, nullable) | Populated only when FAILED | Null for 100% of SUCCESS rows, populated for 100% of FAILED rows |
| `retry_count` | int | Retries within this activation attempt, 0-3 | **100% coincident with FAILED status — exclude as a predictive/causal feature (leakage), see Notebook 1 §7.2** |

## 3. `network_logs.csv` — Fact (independent grain) | Grain: 1 row per network health sample | 250,000 rows | Owner: Telecom Operations

| Column | Type | Description | Notes |
|---|---|---|---|
| `log_id` | string (PK) | Unique sample identifier | |
| `timestamp` | datetime | Sample time | Range: 2025-01-01 to 2025-12-30 |
| `network_partner` | string | Telecom partner | Shared dimension with activation_logs, no row-level FK |
| `destination` | string | Country | |
| `region` | string | Region | |
| `latency_ms` | int | Latency, 40-500ms | |
| `packet_loss_pct` | float | Packet loss %, 0-15% | |
| `signal_strength` | int | Signal strength, 10-100 | |
| `signal_quality` | string | Poor / Fair / Good / Excellent | Categorical bucket of signal_strength |
| `network_status` | string | Healthy / Degraded / Outage | |
| `maintenance_flag` | bool | Scheduled maintenance in progress | |
| `bandwidth_mbps` | float | Bandwidth, 5-300 Mbps | |
| `network_generation` | string | 4G / 5G | |

## 4. `support_tickets.csv` — Fact | Grain: 1 row per ticket | 55,424 rows | Owner: Customer Support

| Column | Type | Description | Notes |
|---|---|---|---|
| `ticket_id` | string (PK) | Unique ticket identifier | |
| `activation_id` | string (FK → activation_logs) | Links to the triggering activation | **Every ticket traces to a FAILED activation** — 100% validated in Notebook 1 |
| `order_id` | string | Order identifier | |
| `customer_id` | string (FK → customers) | Links to customer | 100% referential integrity |
| `ticket_created_at` | datetime | When the ticket was opened | Range: 2025-01-03 to 2025-12-31 |
| `issue_category` | string | Activation Failed / Network Connection / QR Code Invalid / Slow Activation / Device Compatibility / Payment Issue | |
| `priority` | string | Low / Medium / High / Critical | |
| `support_channel` | string | Chat / Email / Phone | |
| `assigned_team` | string | Billing / Customer Support / Technical Support / Engineering | |
| `resolution_status` | string | Open / Escalated / Resolved | |
| `resolution_time_hours` | float | Time to resolution, 1-72h | |
| `csat_score` | int | Post-resolution satisfaction, 1-5 | |
| `refund_requested` | bool | Whether a refund was requested | 12.1% of tickets |
| `refund_approved` | bool | Whether the refund was approved | 85.6% approval rate among requests |

## 5. `error_codes.csv` — Dimension (lookup) | Grain: 1 row per error code | 8 rows | Owner: Engineering

| Column | Type | Description |
|---|---|---|
| `error_code` | string (PK) | ERR101-ERR108 |
| `error_name` | string | Human-readable name (e.g. "Invalid SIM Profile") |
| `error_category` | string | Provisioning / Network / Authentication / Device / Configuration / Unknown |
| `severity` | string | Critical / High / Medium / Low |
| `owner_team` | string | Engineering / Telecom Operations / Backend / Product / Technical Support / Customer Support |
| `retry_allowed` | bool | Whether the system permits an automatic retry |
| `customer_message` | string | Customer-facing error text |
| `engineering_action` | string | Internal remediation action |
| `sla_hours` | int | Target resolution SLA (2-24h, see Notebook 2 Q27 for compliance reality) |
| `documentation_url` | string | Internal doc link |

---

## Relationship Summary

| From | To | Key | Cardinality | Integrity |
|---|---|---|---|---|
| `activation_logs.customer_id` | `customers.customer_id` | customer_id | many:1 | 100% valid |
| `support_tickets.activation_id` | `activation_logs.activation_id` | activation_id | many:1 (effectively 1:1 in this data) | 100% valid |
| `support_tickets.customer_id` | `customers.customer_id` | customer_id | many:1 | 100% valid |
| `activation_logs.failure_code` | `error_codes.error_code` | error_code | many:1 (nullable) | 100% valid where populated |
| `network_logs` (partner/region) | `activation_logs` (partner/region) | descriptive, not FK | aggregate join only | N/A — different grain |
