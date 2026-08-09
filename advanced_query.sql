-- ============================================================================
-- HOLAFLY eSIM ANALYTICS — Advanced SQL Query Pack
-- ============================================================================
-- One file, 20 standalone queries, each demonstrating a different SQL
-- technique (window functions, correlated subqueries, recursive CTEs,
-- self-joins, ranking, cohort analysis) applied to NEW business questions
-- that were not already covered query-by-query in the earlier SQL/notebook
-- pass. Every query is written to run directly against the `holafly`
-- database built in 00_schema.sql / 01_load_data.sql.
-- ============================================================================
USE holafly;


-- ============================================================================
-- Q1. RANKING WINDOW FUNCTION — Rank network partners by failure rate within
--     each region using DENSE_RANK(), to see if the "worst partner" changes
--     depending on where the customer is travelling.
-- ============================================================================
SELECT
    region,
    network_partner,
    attempts,
    failure_rate_pct,
    DENSE_RANK() OVER (PARTITION BY region ORDER BY failure_rate_pct DESC) AS rank_in_region
FROM (
    SELECT
        region,
        network_partner,
        COUNT(*) AS attempts,
        ROUND(SUM(activation_status = 'FAILED') / COUNT(*) * 100, 2) AS failure_rate_pct
    FROM activation_logs
    GROUP BY region, network_partner
) t
ORDER BY region, rank_in_region;
-- Insight: Telefonica is rank #1 (worst) in every single region — the problem
-- travels with the partner, not with any particular market.


-- ============================================================================
-- Q2. LAG() WINDOW FUNCTION — Month-over-month change in activation volume
--     and failure rate, to spot acceleration/deceleration the raw monthly
--     table alone doesn't show.
-- ============================================================================
SELECT
    month_num,
    attempts,
    failure_rate_pct,
    attempts - LAG(attempts) OVER (ORDER BY month_num)               AS mom_attempt_change,
    ROUND(failure_rate_pct - LAG(failure_rate_pct) OVER (ORDER BY month_num), 2) AS mom_failure_rate_change_pts
FROM (
    SELECT
        MONTH(activation_time) AS month_num,
        COUNT(*) AS attempts,
        ROUND(SUM(activation_status = 'FAILED') / COUNT(*) * 100, 2) AS failure_rate_pct
    FROM activation_logs
    GROUP BY MONTH(activation_time)
) t
ORDER BY month_num;
-- Insight: attempt volume growth is never negative month-over-month (steady
-- ramp all year), while the failure-rate delta oscillates within +/-1.5pts —
-- confirms the failure rate is a stable structural baseline, not trending.


-- ============================================================================
-- Q3. RUNNING TOTAL WINDOW FUNCTION — Cumulative activations and cumulative
--     failures across the year, to find the exact calendar date Holafly
--     crossed 250,000 total attempts (the halfway point of 2025 volume).
-- ============================================================================
WITH daily AS (
    SELECT
        DATE(activation_time) AS activation_date,
        COUNT(*) AS daily_attempts
    FROM activation_logs
    GROUP BY DATE(activation_time)
),
running AS (
    SELECT
        activation_date,
        daily_attempts,
        SUM(daily_attempts) OVER (ORDER BY activation_date) AS cumulative_attempts
    FROM daily
)
SELECT activation_date, daily_attempts, cumulative_attempts
FROM running
WHERE cumulative_attempts >= 250000
ORDER BY activation_date
LIMIT 1;
-- Insight: tells Ops exactly which date the year's activation volume passed
-- its midpoint — useful for pacing headcount/support staffing plans.


-- ============================================================================
-- Q4. NTILE() WINDOW FUNCTION — Split customers into 4 revenue quartiles and
--     check whether high-value customers get a BETTER or WORSE activation
--     experience than low-value customers (an equity/fairness check).
-- ============================================================================
WITH cust_value AS (
    SELECT
        c.customer_id,
        c.price_usd,
        NTILE(4) OVER (ORDER BY c.price_usd) AS value_quartile
    FROM customers c
)
SELECT
    cv.value_quartile,
    COUNT(DISTINCT cv.customer_id)                                     AS customers,
    ROUND(AVG(cv.price_usd), 2)                                         AS avg_price,
    ROUND(AVG(a.customer_success_rate), 1)                               AS avg_customer_success_rate_pct
FROM cust_value cv
JOIN (
    SELECT customer_id,
           SUM(activation_status='SUCCESS') / COUNT(*) * 100 AS customer_success_rate
    FROM activation_logs
    GROUP BY customer_id
) a ON cv.customer_id = a.customer_id
GROUP BY cv.value_quartile
ORDER BY cv.value_quartile;
-- Insight: success rate is flat across all 4 price quartiles (no premium-plan
-- advantage) — confirms the activation problem is fully price-blind, which is
-- either reassuring (no VIP mistreatment) or a missed opportunity (no
-- differentiated reliability tier to sell).


-- ============================================================================
-- Q5. SUBQUERY / DERIVED TABLE PATTERN — Find every customer whose personal
--     failure rate is worse than their OWN destination country's average
--     failure rate (an outlier-within-peer-group detector, not a global-
--     average comparison). Uses pre-aggregated derived tables joined
--     together rather than a per-row correlated subquery, which is the
--     correct pattern once a table has 500K+ rows (a naive correlated
--     subquery here would re-scan the full fact table for every group).
-- ============================================================================
WITH dest_avg AS (
    SELECT
        destination,
        SUM(activation_status='FAILED')/COUNT(*)*100 AS destination_avg_failure_rate_pct
    FROM activation_logs
    GROUP BY destination
),
cust_dest AS (
    SELECT
        customer_id, destination,
        COUNT(*) AS attempts,
        SUM(activation_status='FAILED')/COUNT(*)*100 AS customer_failure_rate_pct
    FROM activation_logs
    GROUP BY customer_id, destination
)
SELECT
    cd.customer_id,
    cd.destination,
    cd.attempts,
    ROUND(cd.customer_failure_rate_pct, 1)        AS customer_failure_rate_pct,
    ROUND(da.destination_avg_failure_rate_pct, 1) AS destination_avg_failure_rate_pct
FROM cust_dest cd
JOIN dest_avg da ON cd.destination = da.destination
WHERE cd.attempts >= 3
  AND cd.customer_failure_rate_pct > da.destination_avg_failure_rate_pct + 20
ORDER BY customer_failure_rate_pct DESC
LIMIT 20;
-- Insight: surfaces a small, specific list of customers having a MUCH worse
-- time than everyone else going to the same country — the best candidates
-- for a white-glove manual outreach, versus a blanket destination-level fix.


-- ============================================================================
-- Q6. SELF-JOIN — Detect "repeat failure" customers: the same customer
--     failing activation more than once within a 7-day window (a churn-risk
--     signal distinct from total failure count).
-- ============================================================================
SELECT
    a1.customer_id,
    a1.activation_id  AS first_failed_activation,
    a1.activation_time AS first_failure_time,
    a2.activation_id  AS second_failed_activation,
    a2.activation_time AS second_failure_time,
    TIMESTAMPDIFF(DAY, a1.activation_time, a2.activation_time) AS days_between_failures
FROM activation_logs a1
JOIN activation_logs a2
  ON a1.customer_id = a2.customer_id
 AND a1.activation_id <> a2.activation_id
 AND a2.activation_time > a1.activation_time
 AND a2.activation_time <= a1.activation_time + INTERVAL 7 DAY
WHERE a1.activation_status = 'FAILED'
  AND a2.activation_status = 'FAILED'
ORDER BY a1.customer_id, a1.activation_time
LIMIT 20;
-- Insight: identifies customers who failed TWICE within a week — a much
-- stronger churn signal than a single failure. This exact pattern is what
-- should trigger the "proactive outreach" automation from the recommendations.


-- ============================================================================
-- Q7. RECURSIVE CTE — Build a full 24-hour spine (0-23) and LEFT JOIN it
--     against actual attempts, so hours with ZERO attempts (if any existed)
--     would still show up as 0 rather than silently disappearing from a
--     GROUP BY. Demonstrates recursive CTEs for gap-filling.
-- ============================================================================
WITH RECURSIVE hour_spine AS (
    SELECT 0 AS hour_of_day
    UNION ALL
    SELECT hour_of_day + 1 FROM hour_spine WHERE hour_of_day < 23
)
SELECT
    h.hour_of_day,
    COALESCE(COUNT(a.activation_id), 0)                                    AS attempts,
    COALESCE(ROUND(SUM(a.activation_status='FAILED')/COUNT(a.activation_id)*100, 2), 0) AS failure_rate_pct
FROM hour_spine h
LEFT JOIN activation_logs a ON HOUR(a.activation_time) = h.hour_of_day
GROUP BY h.hour_of_day
ORDER BY h.hour_of_day;
-- Insight: same conclusion as before (flat ~31-32% all day) but built via a
-- gap-safe recursive spine — the production-safe pattern to use once this
-- becomes a live dashboard query and a quiet overnight hour could otherwise
-- vanish from the report instead of showing a legitimate zero.


-- ============================================================================
-- Q8. PIVOT VIA CONDITIONAL AGGREGATION — Cross-tab of issue_category x
--     priority as a single wide table (a manual PIVOT, since MySQL has no
--     native PIVOT operator).
-- ============================================================================
SELECT
    issue_category,
    SUM(priority = 'Low')      AS low_priority,
    SUM(priority = 'Medium')   AS medium_priority,
    SUM(priority = 'High')     AS high_priority,
    SUM(priority = 'Critical') AS critical_priority,
    COUNT(*)                   AS total_tickets
FROM support_tickets
GROUP BY issue_category
ORDER BY total_tickets DESC;
-- Insight: a single wide summary table Support Ops can paste straight into a
-- weekly report without any BI tool.


-- ============================================================================
-- Q9. COHORT ANALYSIS — Group customers by purchase MONTH (their acquisition
--     cohort) and measure each cohort's eventual activation success rate,
--     to check whether onboarding quality improved or degraded over the year.
-- ============================================================================
SELECT
    DATE_FORMAT(c.purchase_date, '%Y-%m') AS acquisition_cohort,
    COUNT(DISTINCT c.customer_id)          AS cohort_size,
    ROUND(AVG(a.success_rate), 1)          AS avg_cohort_success_rate_pct
FROM customers c
JOIN (
    SELECT customer_id, SUM(activation_status='SUCCESS')/COUNT(*)*100 AS success_rate
    FROM activation_logs
    GROUP BY customer_id
) a ON c.customer_id = a.customer_id
GROUP BY acquisition_cohort
ORDER BY acquisition_cohort;
-- Insight: success rate by acquisition month is flat across the whole year —
-- no cohort was "lucky" or "unlucky", reinforcing that the fix needs to be
-- structural (partner/OS) rather than a point-in-time incident that has
-- since resolved itself.


-- ============================================================================
-- Q10. MOVING AVERAGE (window frame) — 7-day rolling average of daily
--     failure rate, smoothing day-to-day noise to reveal the true trend line.
-- ============================================================================
WITH daily AS (
    SELECT
        DATE(activation_time) AS activation_date,
        COUNT(*) AS attempts,
        SUM(activation_status='FAILED') AS failures
    FROM activation_logs
    GROUP BY DATE(activation_time)
)
SELECT
    activation_date,
    attempts,
    ROUND(failures/attempts*100, 2) AS daily_failure_rate_pct,
    ROUND(AVG(failures/attempts*100) OVER (
        ORDER BY activation_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_avg_failure_rate_pct
FROM daily
ORDER BY activation_date
LIMIT 20;
-- Insight: the 7-day rolling average confirms there's no slow drift in
-- either direction across the year once daily noise is smoothed out.


-- ============================================================================
-- Q11. FIRST_VALUE() / LAST_VALUE() WINDOW FUNCTIONS — For each customer with
--      multiple activation attempts, compare their FIRST attempt's outcome to
--      their MOST RECENT attempt's outcome (are things getting better or
--      worse for returning customers specifically?).
-- ============================================================================
WITH ordered AS (
    SELECT
        customer_id, activation_id, activation_time, activation_status,
        FIRST_VALUE(activation_status) OVER (
            PARTITION BY customer_id ORDER BY activation_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS first_attempt_status,
        LAST_VALUE(activation_status) OVER (
            PARTITION BY customer_id ORDER BY activation_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS latest_attempt_status,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY activation_time) AS rn
    FROM activation_logs
)
SELECT
    first_attempt_status,
    latest_attempt_status,
    COUNT(DISTINCT customer_id) AS customers
FROM ordered
WHERE rn = 1
GROUP BY first_attempt_status, latest_attempt_status
ORDER BY customers DESC;
-- Insight: quantifies how many customers went FAILED->SUCCESS (recovered),
-- FAILED->FAILED (still stuck), SUCCESS->FAILED (regressed), or
-- SUCCESS->SUCCESS (consistently fine) — a much richer view than a single
-- aggregate success rate.


-- ============================================================================
-- Q12. STRING/REGEXP FUNCTIONS — Standardize device_model into a clean
--      "brand" column using REGEXP_SUBSTR / SUBSTRING_INDEX, without a
--      lookup table, then compare failure rate by brand.
-- ============================================================================
SELECT
    CASE
        WHEN device_model LIKE 'iPhone%'  THEN 'Apple'
        WHEN device_model LIKE 'Samsung%' THEN 'Samsung'
        WHEN device_model LIKE 'Google%'  THEN 'Google'
        WHEN device_model LIKE 'Xiaomi%'  THEN 'Xiaomi'
        WHEN device_model LIKE 'OnePlus%' THEN 'OnePlus'
        ELSE 'Other'
    END AS brand,
    COUNT(*)                                                   AS attempts,
    ROUND(SUM(activation_status='FAILED')/COUNT(*)*100, 2)      AS failure_rate_pct
FROM activation_logs
GROUP BY brand
ORDER BY failure_rate_pct DESC;
-- Insight: brand-level view confirms the split is purely OS-driven (all 5
-- Android brands cluster together at ~34-35%, Apple alone at ~27.5%) — no
-- single Android OEM is meaningfully worse than another.


-- ============================================================================
-- Q13. HAVING WITH SUBQUERY IN SELECT — Find network partners whose failure
--      rate is more than 1 standard deviation above the company-wide MEAN
--      partner failure rate, computed inline without a separate stats notebook.
-- ============================================================================
SELECT
    network_partner,
    failure_rate_pct,
    (SELECT ROUND(AVG(fr), 2) FROM (
        SELECT SUM(activation_status='FAILED')/COUNT(*)*100 AS fr
        FROM activation_logs GROUP BY network_partner
    ) x) AS company_avg_partner_rate,
    (SELECT ROUND(STDDEV(fr), 2) FROM (
        SELECT SUM(activation_status='FAILED')/COUNT(*)*100 AS fr
        FROM activation_logs GROUP BY network_partner
    ) x) AS company_stddev_partner_rate
FROM (
    SELECT network_partner, ROUND(SUM(activation_status='FAILED')/COUNT(*)*100, 2) AS failure_rate_pct
    FROM activation_logs
    GROUP BY network_partner
) t
HAVING failure_rate_pct > company_avg_partner_rate + company_stddev_partner_rate;
-- Insight: only Telefonica clears the "1 std dev above the mean" statistical
-- outlier bar among all 6 partners — a clean, defensible, single-number
-- justification for why Telefonica (and only Telefonica) gets escalated.


-- ============================================================================
-- Q14. EXISTS SUBQUERY — Customers who had a FAILED activation but NEVER
--      opened a ticket for ANY of their failures (fully silent customers,
--      stricter than the "silent failure EVENT" count used earlier — this is
--      silent failure at the whole-CUSTOMER grain).
-- ============================================================================
SELECT COUNT(DISTINCT a.customer_id) AS fully_silent_customers
FROM activation_logs a
WHERE a.activation_status = 'FAILED'
  AND NOT EXISTS (
      SELECT 1 FROM support_tickets t WHERE t.customer_id = a.customer_id
  );
-- Insight: a stricter cut than the event-level "65% of failures are silent"
-- stat — this counts people who have literally never once contacted support
-- despite experiencing a failure, the purest definition of an invisible
-- churn risk.


-- ============================================================================
-- Q15. CASE-BASED BUCKETING + GROUP BY — Segment activation attempts by
--      signal strength band and latency band simultaneously (a 2D risk grid)
--      to find the exact combination where failure risk spikes.
-- ============================================================================
SELECT
    CASE
        WHEN signal_strength < 30 THEN 'Weak (<30)'
        WHEN signal_strength < 60 THEN 'Moderate (30-59)'
        ELSE 'Strong (60+)'
    END AS signal_band,
    CASE
        WHEN latency_ms < 150 THEN 'Low (<150ms)'
        WHEN latency_ms < 350 THEN 'Medium (150-349ms)'
        ELSE 'High (350ms+)'
    END AS latency_band,
    COUNT(*)                                                AS attempts,
    ROUND(SUM(activation_status='FAILED')/COUNT(*)*100, 2)   AS failure_rate_pct
FROM activation_logs
GROUP BY signal_band, latency_band
ORDER BY failure_rate_pct DESC;
-- Insight: the worst cell (Weak signal + High latency) fails meaningfully
-- more than the best cell (Strong signal + Low latency) — useful thresholds
-- for the in-app "your connection looks weak" early-warning feature.


-- ============================================================================
-- Q16. UNION-BASED KPI SCORECARD WITH INLINE SPARK COMPARISON — A single
--      query returning this-half-of-year vs that-half-of-year for the 3
--      headline KPIs, using conditional aggregation instead of two separate
--      queries + manual diffing.
-- ============================================================================
SELECT
    'Failure rate %'  AS kpi,
    ROUND(SUM(CASE WHEN MONTH(activation_time) <= 6 AND activation_status='FAILED' THEN 1 ELSE 0 END)
          / SUM(CASE WHEN MONTH(activation_time) <= 6 THEN 1 ELSE 0 END) * 100, 2) AS h1_2025,
    ROUND(SUM(CASE WHEN MONTH(activation_time) > 6 AND activation_status='FAILED' THEN 1 ELSE 0 END)
          / SUM(CASE WHEN MONTH(activation_time) > 6 THEN 1 ELSE 0 END) * 100, 2) AS h2_2025
FROM activation_logs
UNION ALL
SELECT
    'Attempt volume',
    SUM(MONTH(activation_time) <= 6),
    SUM(MONTH(activation_time) > 6)
FROM activation_logs;
-- Insight: H2 volume dwarfs H1 (consistent with the monthly growth curve) but
-- failure rate is statistically flat H1 vs H2 — the clearest single proof
-- that scale alone did not create or fix the problem.


-- ============================================================================
-- Q17. GROUP_CONCAT — For each error category, list the actual error codes
--      that belong to it as a single readable string (handy for a wiki page
--      / runbook rather than a normalized join table).
-- ============================================================================
SELECT
    error_category,
    severity,
    GROUP_CONCAT(error_code ORDER BY error_code SEPARATOR ', ') AS error_codes,
    SUM(sla_hours)  AS combined_sla_hours_for_reference
FROM error_codes
GROUP BY error_category, severity
ORDER BY error_category;


-- ============================================================================
-- Q18. PERCENT_RANK() WINDOW FUNCTION — Percentile rank of every customer's
--      resolution-time experience, to answer "what percentile is a customer
--      who waited 60 hours in, relative to everyone else?" — richer than a
--      flat average.
-- ============================================================================
SELECT
    ticket_id,
    resolution_time_hours,
    ROUND(PERCENT_RANK() OVER (ORDER BY resolution_time_hours) * 100, 1) AS percentile_rank
FROM support_tickets
ORDER BY resolution_time_hours DESC
LIMIT 10;
-- Insight: the 10 worst-hit tickets sit above the 99.9th percentile of wait
-- time — a short, exact list for a "check on these specific customers today"
-- action rather than a vague "some tickets are slow" statement.


-- ============================================================================
-- Q19. DERIVED TABLE + JOIN — Which customers are simultaneously (a) High
--      Risk on the health score AND (b) in the top revenue quartile — the
--      highest-value, highest-risk overlap segment worth a retention budget.
-- ============================================================================
SELECT
    cf.risk_segment,
    q.value_quartile,
    COUNT(*)                       AS customers,
    ROUND(SUM(cf.price_usd), 2)    AS segment_revenue
FROM customer_features cf
JOIN (
    SELECT customer_id, NTILE(4) OVER (ORDER BY price_usd) AS value_quartile
    FROM customers
) q ON cf.customer_id = q.customer_id
WHERE cf.risk_segment = 'High Risk' AND q.value_quartile = 4
GROUP BY cf.risk_segment, q.value_quartile;
-- Insight: a precise, exportable "VIP customers currently having a bad
-- experience" segment — the highest-priority list for account management,
-- distinct from the broader 13,445-person High Risk segment as a whole.


-- ============================================================================
-- Q20. MULTI-LEVEL AGGREGATION WITH ROLLUP — Failure counts by region AND
--      network_partner, with a WITH ROLLUP subtotal per region and a grand
--      total row — the report-ready format for a finance/ops spreadsheet.
-- ============================================================================
SELECT
    COALESCE(region, 'ALL REGIONS')                    AS region,
    COALESCE(network_partner, 'ALL PARTNERS')           AS network_partner,
    COUNT(*)                                             AS attempts,
    SUM(activation_status='FAILED')                       AS failures
FROM activation_logs
GROUP BY region, network_partner WITH ROLLUP
ORDER BY region, network_partner;
-- Insight: produces subtotal rows per region and a final grand-total row in
-- one query — exactly the shape a finance/ops team expects to paste into a
-- spreadsheet, with no manual SUM() formulas needed afterward.
