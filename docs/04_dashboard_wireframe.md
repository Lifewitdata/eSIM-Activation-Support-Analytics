# Phase 8 — Dashboard Design (Power BI / Tableau)

**Data model:** star schema — `activation_logs` and `support_tickets` as fact tables, `customers`, `error_codes`, and a date table as dimensions, `network_logs` pre-aggregated to a `network_partner_daily_health` summary table to keep it joinable at BI-tool grain. The `customer_features.csv` output from Notebook 3 (health score, risk segment) is imported as a dimension extension on `customers`.

Six pages, one per primary stakeholder audience. Every page follows the same layout convention: **KPI strip (top) → primary chart (left, 60%) → supporting breakdown (right, 40%) → filter pane (left rail)**, with a global filter pane (Date Range, Region, Network Partner, Device OS) pinned across all pages via a bookmark-synced filter.

---

## Page 1 — Executive Overview
**Audience:** Leadership | **Purpose:** one-glance health check + the 3 headline findings

- **KPI strip:** Activation Success Rate (68.3%, red vs 85% target) · Total Attempts (500K) · Total Tickets (55.4K) · SLA Compliance (26.0%, red) · Avg CSAT (3.74/5) · Total Revenue ($1.57M)
- **Primary chart:** Monthly trend — attempt volume (bar) vs failure rate (line, secondary axis) — shows volume scaling while failure rate stays flat (the "problem won't fix itself" story)
- **Supporting:** 3 callout cards — "Telefonica +7.8pts", "Android +6.9pts", "65% of failures never reach Support" — each drills through to Page 2/3
- **Filters:** Date range, Region
- **Drill-down:** click any KPI card → jumps to the relevant detail page
- **Tooltip:** hovering the trend line shows attempts/failures/rate for that month

## Page 2 — Activation Performance
**Audience:** Product & Engineering | **Purpose:** where exactly is the funnel breaking

- **KPI strip:** Success Rate · Silent Failure Rate · Avg Retry Count · Zero-Success Customers
- **Primary chart:** Funnel visual (Purchased → Attempted → Succeeded → Ticketed → Resolved)
- **Supporting:** Failure rate heat-matrix (Network Partner × Device OS), sortable bar of failure rate by device model
- **Filters:** Network Partner, Device OS, Region, Plan Type
- **Drill-down:** click a heat-matrix cell → filtered list of underlying error codes for that segment
- **Tooltip:** cell shows attempts, failures, failure rate %, and rank vs company average

## Page 3 — Network Performance
**Audience:** Telecom Operations | **Purpose:** partner scorecard & network health monitoring

- **KPI strip:** Network Uptime % · Avg Latency · Avg Packet Loss · Partner Reliability Score (lowest partner flagged red)
- **Primary chart:** Partner Reliability Score bar (from Notebook 3 feature), with a secondary panel showing that latency/packet-loss are *not* significantly different by partner (the "it's not the network" evidence)
- **Supporting:** Outage/Degraded sample count trend by partner over time; network generation (4G/5G) split
- **Filters:** Network Partner, Region, Date Range
- **Drill-down:** click a partner → partner detail page with time series of health status
- **Tooltip:** shows outage count, degraded count, and % healthy for the hovered period

## Page 4 — Customer Experience
**Audience:** Product & CX Leadership | **Purpose:** who is affected and how badly

- **KPI strip:** Avg CSAT · % High Risk customers · Refund Request Rate · Refund Approval Rate
- **Primary chart:** Risk segment distribution (Low/Medium/High) with revenue exposure by segment
- **Supporting:** CSAT distribution histogram; refund requests by issue category
- **Filters:** Customer Segment, Plan Type, Risk Segment
- **Drill-down:** click "High Risk" segment → exportable customer list for CRM outreach
- **Tooltip:** customer segment tooltip shows count, avg health score, avg CSAT

## Page 5 — Support Operations
**Audience:** Customer Support Leadership | **Purpose:** operational bottlenecks & SLA reality

- **KPI strip:** SLA Compliance % (headline red metric) · Avg Resolution Time · Open+Escalated ticket count · Support Efficiency Score by team
- **Primary chart:** SLA compliance by error code (the "inverted SLA" chart — tightest SLAs missed most)
- **Supporting:** Resolution time & CSAT by team (dual-axis); ticket volume by channel and category
- **Filters:** Assigned Team, Priority, Support Channel, Resolution Status
- **Drill-down:** click a team → ticket-level list filtered to that team, sorted by SLA breach severity
- **Tooltip:** SLA bar tooltip shows target hours, actual avg hours, and n tickets

## Page 6 — Engineering Insights
**Audience:** Engineering | **Purpose:** prioritized, evidence-ranked fix list

- **KPI strip:** Failure Codes with <20% SLA compliance (count) · Top contributing segment (Telefonica+Android, 11.6% of all failures) · Pareto coverage (7 of 8 codes needed for 80%)
- **Primary chart:** Pareto chart of failure-code contribution (shows the "anti-Pareto" flat distribution — a deliberate, honest visual since it argues against a single-fix narrative)
- **Supporting:** Contribution table — partner × OS segment, failure count, % of total failures, statistical significance flag (from Notebook 4 chi-square/z-test results)
- **Filters:** Error Category, Severity, Owner Team
- **Drill-down:** click a failure code → linked engineering documentation URL (from `error_codes.documentation_url`) and SLA compliance trend
- **Tooltip:** shows error name, category, severity, owner team, and SLA hours

---

## Cross-page design notes
- **Color system:** Holafly orange (`#FF6A00`) reserved exclusively for "attention/risk" values (Telefonica, High Risk, SLA breaches); navy (`#1B2A4A`) for neutral/baseline; green for "healthy" states — consistent with the notebook chart palette so exec-deck screenshots and dashboard screenshots feel like one product.
- **Refresh cadence:** Pages 1-2 (activation) refresh daily; Page 3 (network) refreshes daily from `network_logs`; Page 5 (support) refreshes in near-real-time if the helpdesk supports a live connector; Page 6 (engineering) refreshes weekly, matching the `activation_risk_tier` feature's recommended cadence.
- **Row-level security:** Support Ops sees Page 5 by default; Engineering sees Page 6; Leadership sees all six — implemented via standard Power BI RLS roles mapped to `assigned_team`/`owner_team`.
