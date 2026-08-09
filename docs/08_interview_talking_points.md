# Interview Talking Points — How to Present This Project

Use this as a cheat sheet for behavioral/case interviews at companies like Holafly, Microsoft, Amazon, Booking.com, Uber, Revolut, Stripe.

## The 60-second summary
"I analyzed 500K eSIM activation attempts, 250K network health logs, and 55K support tickets to figure out why ~32% of activations were failing. Rather than stopping at 'here's a correlation,' I ran formal statistical tests to separate real drivers from noise — region and hour-of-day looked interesting in raw charts but weren't statistically significant, while network partner and device OS were. The most useful finding was actually a negative result: network telemetry for the worst-performing partner (Telefonica) was statistically indistinguishable from everyone else's, which told us the fix was an API/provisioning integration issue, not a 'renegotiate the network contract' issue — a much cheaper, faster fix to prioritize."

## Questions this project lets you answer well

**"Tell me about a time you found something counter-intuitive in data."**
→ The ANOVA result that Telefonica's network latency wasn't significantly different from other partners, despite its activation failure rate being significantly worse. Walk through how that changed the recommendation from a Telecom Ops ask to an Engineering ask — and why checking that assumption mattered (would have wasted a quarter renegotiating a network SLA that wasn't the actual problem).

**"How do you avoid p-hacking / cherry-picking findings?"**
→ I deliberately reported the negative results (region not significant, channel not significant, latency-by-partner not significant) alongside the positive ones, and used the ruled-out dimensions to build credibility for the ones that mattered. The Pareto analysis on error codes also came back "flat" rather than showing an 80/20 pattern — I reported that honestly instead of forcing a dominant-cause narrative that the data didn't support.

**"Walk me through how you'd quantify business impact when the answer isn't a single clean number."**
→ I split revenue impact into three tiers with different confidence levels — realized loss (approved refunds, a hard number), near-term risk (a defined cohort with zero successful activations), and broader exposure (customers touched by at least one silent failure). Presenting one blended number would have either understated the urgent case or overstated what's actually "lost" — the three-tier framing let each stakeholder (Finance vs Leadership vs Product) use the number appropriate to their decision.

**"How do you handle a messy multi-table dataset with unclear relationships?"**
→ Before writing any analysis code, I validated grain and cardinality explicitly (e.g. discovering `customers.csv` has no order_id and is a profile snapshot while `activation_logs` is the true event-level fact table) — that shaped every join decision downstream. I also found that `network_logs` shares descriptive columns with `activation_logs` but not a row-level key, so I made an explicit, documented decision to integrate it at an aggregate grain rather than forcing a row-level join that would have silently misrepresented the data.

**"Describe a data quality issue you caught."**
→ `retry_count` was 100% collinear with the FAILED outcome — it only gets populated within a failed session, so including it in any "predictor of failure" analysis would have been circular reasoning dressed up as insight (a correlation of 0.90 that means nothing causal). Catching and explicitly excluding leakage features like this is exactly the kind of thing that separates a rigorous analysis from a superficially impressive one.

**"How do you decide what NOT to build a dashboard page for?"**
→ I didn't give hour-of-day or hourly patterns a dashboard page even though I checked it, because it came back flat/non-significant — a dashboard should surface decisions, not just data that happens to exist.

## Artifacts to reference live in an interview
- `notebooks/04_root_cause_and_statistical_analysis.ipynb` — shows statistical rigor
- `docs/05_executive_insights.md` — shows business communication skill
- `docs/04_dashboard_wireframe.md` — shows you think about stakeholders, not just charts
