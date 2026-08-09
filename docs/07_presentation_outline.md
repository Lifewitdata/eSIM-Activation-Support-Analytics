# Presentation Outline — "Why 1 in 3 eSIM Activations Fail (and What To Do About It)"

**Format:** 12-15 slide stakeholder readout, ~20 min + Q&A. Audience: Product, Engineering, Support, Telecom Ops leads + Leadership sponsor.

1. **Title + one-line thesis** — "Activation failure has a specific, fixable root cause — not a diffuse mystery — and it's costing us at least $88K/year today, with $1M+ in exposure."
2. **The problem in one chart** — Q1 pie: 68.3% success / 31.7% failure, with the "1 in 3 travelers" framing.
3. **The funnel** — where the 500K attempts go, ending on the 65% silent-failure stat (the surprise slide).
4. **What it's NOT** — region, hour-of-day, customer segment, support channel — all ruled out with the flat-rate charts (builds credibility by showing rigor, not just cherry-picked wins).
5. **What it IS (#1)** — Telefonica: the bar chart + the statistical confirmation (z-test, non-overlapping CIs).
6. **The twist** — network health is fine for Telefonica too (ANOVA not significant) → it's an integration problem, not a network problem. This is the "aha" slide.
7. **What it IS (#2)** — Android vs iOS, consistent across every device model, 61% of all failures.
8. **The compounding effect** — Telefonica + Android combined = 41.1%, 11.6% of all company-wide failures from one segment.
9. **The cost** — three-tier revenue framing: realized ($88K refunds), near-term risk ($41K zero-success cohort), broader exposure ($1.0M silent failures).
10. **The support-side story** — SLA compliance 26%, inverted severity pattern (tightest SLAs missed most).
11. **The recommendation** — combined Telefonica-integration + Android-flow fix as the #1 priority, plus the SLA reset workshop.
12. **The ask** — resourcing for the fix, target KPIs (85% success rate, 80% SLA compliance, 4.2 CSAT), and a 2-quarter timeline.
13. **Appendix slides** — full statistical test table, dashboard preview, data quality summary (available on request, not presented live).

**Presenter notes:** lead with the "what it's NOT" slide before the "what it IS" slides — ruling things out first is what makes the Telefonica/Android finding land as rigorous rather than a hunch.
