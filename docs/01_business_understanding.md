# Phase 1 — Business Understanding

## Business Problem

Holafly sells prepaid eSIM data plans to international travelers. The core product promise is simple: **buy a plan, scan a QR code, get connected the moment you land.** When activation fails, the customer is stranded exactly when they need connectivity most — to reach rideshare, maps, translation, or family. This project investigates why roughly **1 in 3 activation attempts fails**, who it affects, what it costs, and what Product, Engineering, Customer Support, and Telecom Operations should each do about it.

## Stakeholders

| Stakeholder | What they need from this project |
|---|---|
| **Product** | Where the customer journey breaks, and which fixes move the success-rate KPI most |
| **Engineering** | A prioritized, evidence-backed root-cause list (not "everything is broken") |
| **Telecom Operations** | Partner-level performance data to drive vendor conversations and SLAs |
| **Customer Support Leadership** | Ticket volume drivers, SLA compliance reality, and team efficiency benchmarks |
| **Finance / Leadership** | Quantified revenue impact and a defensible business case for investment |

## Business Objectives

1. Quantify the true scale of the activation failure problem (not just what reaches Support).
2. Identify the specific, statistically-defensible root cause(s) — not a list of everything that correlates.
3. Quantify the operational and financial cost of the status quo.
4. Translate findings into prioritized, owned, resourced recommendations.

## Key Business Questions

- Why are eSIM activations failing, and is it one cause or many?
- Which countries generate the highest failure rates? *(Spoiler: none — geography is a red herring; see Notebook 4.)*
- Which telecom partners perform poorly, and is it a network problem or an integration problem?
- Which devices create the highest support burden?
- Which customers are most affected, and are some segments disproportionately hurt?
- How much revenue is potentially lost, refunded, or put at risk?
- What operational improvements should Holafly implement, by team, this quarter?

## KPIs & Success Metrics

| KPI | Current (2025) | Target |
|---|---|---|
| Activation success rate | 68.3% | ≥ 85% |
| Silent failure rate (failures never reaching Support) | 65.0% | < 40% (via better in-app telemetry, not just fewer failures) |
| Overall SLA compliance | 26.0% | ≥ 80% for Critical/High severity codes |
| Average CSAT | 3.74 / 5 | ≥ 4.2 / 5 |
| Zero-success customer count (quarterly) | 2,672 (annualized) | < 500/quarter |
| Telefonica failure-rate gap vs peer average | +7.8 pts | < 2 pts |
| Android vs iOS failure-rate gap | +6.9 pts | < 2 pts |

## Assumptions

1. `customers.csv` represents a customer profile / most-recent-purchase snapshot (no `order_id`), while `activation_logs.csv` is the authoritative record of each individual activation attempt — confirmed in Notebook 1.
2. `network_logs.csv` is an independently-sampled operational telemetry feed, not a row-level match to specific activation attempts; it is integrated at the partner/region aggregate level.
3. `price_usd` in `customers.csv` is treated as the booked revenue for that customer's most recent/primary plan, used as a proxy for revenue-at-risk calculations.
4. All monetary figures are in USD as provided in the source data; no currency conversion was required.
5. The dataset covers calendar year 2025 in full (Jan 1 – Dec 30/31), so seasonality analysis (Notebook 2, Q11) reflects a genuine full-year pattern rather than a partial-year artifact.

## Risks

| Risk | Mitigation |
|---|---|
| Recommending a fix based on correlation, not causation | Every headline claim in this project is backed by a formal statistical test (chi-square, t-test, ANOVA) in Notebook 4, and counter-evidence (e.g. network ANOVA ruling out a network explanation for Telefonica) is reported alongside supporting evidence |
| Overstating financial impact | Three separate, clearly-labeled revenue figures are reported (realized loss, near-term risk, broader exposure) rather than one inflated headline number — see Notebook 2 Q35 |
| Silent-failure estimate being a Product/Engineering blind spot with no current instrumentation to validate | Recommended as the #1 near-term Engineering action — Notebook 2 Q3 and `06_final_recommendations.md` |
| Data is unusually clean (see `03_data_quality_report.md`) — a production Holafly dataset would likely have more real-world messiness (duplicate loyalty IDs, timezone drift, partner-name inconsistencies) | Data quality checks were built comprehensively and defensively so the same pipeline holds up if noisier data arrives in a future refresh |
