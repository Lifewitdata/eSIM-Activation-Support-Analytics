<div align="center">

#  eSIM Activation & Support Analytics

### Why does 1 in 3 eSIM activations fail — and what is it costing the business?

An end-to-end data analytics project diagnosing a 32% activation failure rate across 500K records, isolating its statistically significant root causes, and quantifying its revenue impact.

[![Python](https://img.shields.io/badge/Python-Polars%20%7C%20Pandas-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Jupyter](https://img.shields.io/badge/Jupyter-Notebook-F37626?style=flat-square&logo=jupyter&logoColor=white)](https://jupyter.org/)
[![SciPy](https://img.shields.io/badge/SciPy-Statistical%20Testing-8CAAE6?style=flat-square&logo=scipy&logoColor=white)](https://scipy.org/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](#license)

</div>

---

## TL;DR

Holafly's eSIM activations were failing at a **31.7% rate** across 500,000 attempts with no known cause. This project ran chi-square tests, two-proportion z-tests, and ANOVA across five relational datasets to find out why — and proved the answer wasn't geography, time of day, or even the network itself.

| | |
|---|---|
| **The culprit** | Telefonica (+7.8 pts) and Android (+6.9 pts) — the only two statistically significant drivers (p < 0.001) |
| **The twist** | ANOVA showed Telefonica's *network* telemetry is indistinguishable from its peers — the failure is a provisioning/integration bug, not a network problem |
| **The blind spot** | 65% of failures never generate a support ticket — the real failure rate is invisible to most dashboards |
| **The cost** | $88K in realized refunds, $41K in near-term churn risk, $1.0M+ in broader revenue exposure |
| **The operational gap** | Support SLA compliance is 26% overall — and the most critical-severity issues are met only 0–20% of the time |

---

## Table of contents

- [The problem](#the-problem)
- [Key findings](#key-findings)
- [Tech stack](#tech-stack)
- [Repository structure](#repository-structure)
- [Methodology](#methodology)
- [Quickstart](#quickstart)
- [Sample results](#sample-results)
- [Deliverables](#deliverables)
- [Author](#author)

---

## The problem

Holafly sells prepaid eSIM data plans to international travelers. The core product promise is simple: buy a plan, scan a QR code, get connected the moment you land. When activation fails, the customer is stranded exactly when they need connectivity most.

This project investigates activation failure across five relational datasets — **customers**, **activation logs**, **network logs**, **support tickets**, and **error codes** — to answer the questions Product, Engineering, Support, and Leadership actually need answered:

- Is this a network problem, a device problem, or a process problem?
- Which specific segment of customers is most affected?
- How much is it costing the business — and is that cost realized or just a risk?
- Is Support's stated service commitment (SLA) actually being honored?

---

## Key findings

**1. The root cause is a partner × OS interaction, not geography.**
`DENSE_RANK() OVER (PARTITION BY region ORDER BY failure_rate DESC)` shows Telefonica ranks worst in **every single region** — the failure rate doesn't vary by market (chi-square p = 0.29, not significant), it travels with the partner.

**2. It isn't a network-quality problem.**
Telefonica's raw network telemetry — latency (98.3ms), packet loss, signal strength — is statistically indistinguishable from its five peer partners (ANOVA F = 1.40, p = 0.22). Yet its activation failure rate is 7.8 points higher (z = 42.1, p < 0.001). The gap has to come from provisioning or authentication, not the radio network.

**3. Android carries the volume-weighted majority of failures.**
Every Android brand — Samsung, Xiaomi, OnePlus, Google — clusters at 34–35% failure, while every Apple device sits at ~27.5%. It's an OS-level issue, not a single rogue device.

**4. Failure risk compounds with connection quality — but isn't caused by it.**
A signal-strength × latency risk grid shows failure rate ranging from 14.8% (strong signal, low latency) to 53.9% (weak signal, high latency) — a real, usable early-warning signal, layered on top of the structural partner/OS issue.

**5. The visible cost is a fraction of the real cost.**
65% of failed activations never generate a support ticket. A three-tier revenue model separates what's already lost ($88,459 in approved refunds) from what's at near-term risk ($40,673 tied to customers who never once succeeded) from the broader exposure ($1.0M+ touching customers who hit at least one silent failure).

**6. Support's SLA framework is inverted.**
Overall SLA compliance is 26%. The tightest, most critical-severity SLAs (2–6 hours) are met only 0–21% of the time, while the single lenient 24-hour SLA is met 100% of the time — the opposite of what a healthy SLA structure should look like.

---

## Tech stack

| Layer | Tools |
|---|---|
| **Data processing** | Python, Polars, Pandas |
| **Statistical testing** | SciPy, statsmodels — chi-square, two-proportion z-test, Welch's t-test, one-way ANOVA, Pearson correlation |
| **Database / SQL** | MySQL 8.0 — window functions, recursive CTEs, correlated subqueries, self-joins, `WITH ROLLUP` |
| **Visualization** | Matplotlib, Chart.js |
| **Notebooks** | Jupyter (`nbconvert`, fully executed end-to-end) |

---

## Repository structure

```
holafly_project/
├── notebooks/                          Python analysis, fully executed
│   ├── 01_data_understanding_and_quality.ipynb
│   ├── 02_eda_business_analysis.ipynb          45 business questions
│   ├── 03_feature_engineering.ipynb            Health Score, Risk Segment
│   └── 04_root_cause_and_statistical_analysis.ipynb
├── sql/                                 MySQL 8.0 implementation
      chi-sq/t/F/correlation from raw formulas
│   └── advanced_query_pack.sql          20 queries — window fns, CTEs, self-joins
├── docs/                                Stakeholder-facing deliverables
│   ├── 01_business_understanding.md
│   ├── 02_data_dictionary.md
│   ├── 03_data_quality_report.md
│   ├── 04_dashboard_wireframe.md        6-page Power BI/Tableau design
│   ├── 05_executive_insights.md         25 insights, finding → recommendation
│   ├── 06_final_recommendations.md      per-team action plan
│   ├── 07_presentation_outline.md
│   └── 08_interview_talking_points.md
└── data/raw/                            source CSVs
```

---

## Methodology

The project follows the full analytics lifecycle rather than jumping straight to charts:

`Business Understanding` → `Data Understanding & Quality` → `EDA (45 questions)` → `Feature Engineering` → `Root Cause Analysis` → `Statistical Validation` → `Dashboard Design` → `Executive Insights` → `Recommendations`

Every headline claim is backed by a formal statistical test, not just a chart that looks convincing — and negative results (region, time-of-day, support channel — none of which matter) are reported honestly alongside the positive ones, because ruling things out is what makes the findings that *do* hold up trustworthy.

Both a **Python/Polars** and a **pure MySQL** implementation are included and cross-validated — every statistic (chi-square = 1997.55, z = 42.14, t = 130.46, ANOVA F = 31,654.1) matches to two decimal places across both engines.

---

## Quickstart

**Python**
```bash
pip install polars pandas numpy scipy statsmodels matplotlib pyarrow jupyter
cd notebooks
jupyter nbconvert --to notebook --execute --inplace 02_eda_business_analysis.ipynb
```

**MySQL**
```bash
mysql -uroot < sql/00_schema.sql
mysql -uroot --local-infile=1 < sql/01_load_data.sql
mysql -uroot -t < sql/advanced_query_pack.sql
```

---

## Sample results

| Metric | Value |
|---|---|
| Activation attempts analyzed | 500,000 |
| Overall failure rate | 31.7% |
| Telefonica vs. peer-average failure rate | 38.3% vs. 30.5% (p < 0.001) |
| Android vs. iOS failure rate | 34.4% vs. 27.5% (p < 0.001) |
| Failures with no support ticket | 65% |
| Support SLA compliance | 26% |
| Realized refund cost | $88,459 |
| Revenue exposure (silent failures) | $1.0M+ |

---

## Deliverables

- 4 fully-executed **Jupyter notebooks** with inline charts and statistical output
- 27 standalone **SQL scripts** (schema, load, quality, EDA, root cause, feature engineering, statistics, advanced query pack)
- 8 **stakeholder documents** — business case, data dictionary, DQ report, dashboard wireframe, executive insights, recommendations, presentation outline
- A reusable **customer_features** table (Health Score, Risk Segment) and 4 SQL views (Partner Reliability, Support Efficiency, Activation Risk Tier, SLA Compliance)

---

## Author

Built as an end-to-end, production-style Data Analyst case study — from raw CSVs to an executive-ready business case, in both Python and SQL.

<div align="center">

*If this project was useful or interesting, consider starring the repo.*

</div>
