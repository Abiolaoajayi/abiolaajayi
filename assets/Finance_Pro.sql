
-- create a copy table --


USE Financial_Project;


INSERT INTO bank_income_quarterly
SELECT * FROM data;

SELECT COUNT(*) AS rows_data  FROM data;
SELECT COUNT(*) AS rows_copy  FROM bank_income_quarterly;


-- create a clean base view --

DROP VIEW IF EXISTS v_bank_base;

CREATE VIEW v_bank_base AS
SELECT
  `Ticker`                                AS ticker,
  STR_TO_DATE(`Report Date`, '%Y-%m-%d')  AS report_date,
  `Fiscal Year`                           AS fiscal_year,
  `Fiscal Period`                         AS fiscal_period,
  `Currency`                              AS currency,
  `Shares (Basic)`                        AS shares_basic,
  `Shares (Diluted)`                      AS shares_diluted,
  `Revenue`                               AS revenue,
  `Provision for Loan Losses`             AS provision_loan_losses,
  `Net Revenue after Provisions`          AS net_revenue_after_prov,
  `Total Non-Interest Expense`            AS total_non_interest_exp,
  `Operating Income (Loss)`               AS operating_income,
  `Non-Operating Income (Loss)`           AS non_operating_income,
  `Pretax Income (Loss)`                  AS pretax_income,
  `Income Tax (Expense) Benefit, Net`     AS income_tax_exp_benefit,
  `Income (Loss) from Continuing Operations` AS ni_from_cont_ops,
  `Net Extraordinary Gains (Losses)`      AS net_extraordinary_gains,
  `Net Income`                            AS net_income,
  `Net Income (Common)`                   AS net_income_common
FROM bank_income_quarterly;


-- checking ouptut ---


SELECT ticker, report_date, revenue, net_income
FROM v_bank_base
ORDER BY report_date
LIMIT 10;



-- Key Performance Indicator (KPI) View (Margin & Efficiency)

DROP VIEW IF EXISTS v_bank_income_kpis;

CREATE VIEW v_bank_income_kpis AS
SELECT
  ticker, report_date, fiscal_year, fiscal_period, currency,
  revenue, net_revenue_after_prov, total_non_interest_exp,
  operating_income, pretax_income, income_tax_exp_benefit, net_income, net_income_common,

  ROUND(net_income / NULLIF(revenue,0) * 100, 2)                         AS net_margin_pct,
  ROUND(operating_income / NULLIF(revenue,0) * 100, 2)                    AS operating_margin_pct,
  ROUND(total_non_interest_exp / NULLIF(net_revenue_after_prov,0) * 100, 2) AS efficiency_ratio_pct,
  ROUND(ABS(income_tax_exp_benefit) / NULLIF(pretax_income,0) * 100, 2)    AS tax_rate_pct
FROM v_bank_base;




SELECT ticker, report_date, net_margin_pct, operating_margin_pct, efficiency_ratio_pct, tax_rate_pct
FROM v_bank_income_kpis
ORDER BY report_date
LIMIT 20;


-- order by efficiency ratio --

SELECT ticker, report_date, net_margin_pct, operating_margin_pct, efficiency_ratio_pct, tax_rate_pct
FROM v_bank_income_kpis
ORDER BY efficiency_ratio_pct DESC
LIMIT 20;

-- output ---


/*
The KPI view (v_bank_income_kpis) calculates core banking performance metrics for each quarter. 
For Q4 2019, most regional banks reported net margins in the 25-35% range, with WTBA and SYBT leading the group above 35%. 
Efficiency ratios varied widely, highlighting differences in cost discipline or one-off provisions. 
Tax rates also showed volatility, from near-zero to over 55%, reflecting differences in deferred taxes and local regulation. 
These KPIs provide CFO-level insight into profitability, efficiency, and financial health"
*/



-- Year over Year view (Revenue and Net Income) --

DROP VIEW IF EXISTS v_bank_yoy;

CREATE VIEW v_bank_yoy AS
SELECT
  ticker,
  report_date,
  fiscal_year,
  fiscal_period,
  currency,
  revenue,
  net_income,
  ROUND(
    (revenue - LAG(revenue, 4) OVER (PARTITION BY ticker ORDER BY report_date))
    / NULLIF(LAG(revenue, 4) OVER (PARTITION BY ticker ORDER BY report_date), 0) * 100, 2
  ) AS revenue_yoy_pct,
  ROUND(
    (net_income - LAG(net_income, 4) OVER (PARTITION BY ticker ORDER BY report_date))
    / NULLIF(LAG(net_income, 4) OVER (PARTITION BY ticker ORDER BY report_date), 0) * 100, 2
  ) AS net_income_yoy_pct
FROM v_bank_base;


SELECT * FROM v_bank_yoy
ORDER BY report_date DESC, ticker
LIMIT 10;

/*
The YoY growth analysis (v_bank_yoy) for Q2 2024 highlights mixed performance among regional banks. 
AMAL showed modest revenue growth (+2.25%) but strong earnings growth (+17.89%), 
indicating improved efficiency. BFST delivered solid and balanced growth with revenues up
 nearly 10% and net income up 8.7%. In contrast, ASB, BCBP, and BSBK show null growth metrics 
 due to missing prior-year comparisons in the dataset. Notably, BSBK reported a net loss despite revenue, 
 underlining pressure on profitability. Overall, YoY views provide CFO-level insight into whether 
 growth is driven by revenues or improved cost control.”.
*/

-- Trailing Twelve Months View --

DROP VIEW IF EXISTS v_bank_ttm;

CREATE VIEW v_bank_ttm AS
SELECT
  ticker,
  report_date,
  fiscal_year,
  fiscal_period,
  currency,
  SUM(revenue)          OVER (PARTITION BY ticker ORDER BY report_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS revenue_ttm,
  SUM(net_income)       OVER (PARTITION BY ticker ORDER BY report_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS net_income_ttm,
  SUM(operating_income) OVER (PARTITION BY ticker ORDER BY report_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS op_income_ttm,
  SUM(net_revenue_after_prov) OVER (PARTITION BY ticker ORDER BY report_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS net_rev_after_prov_ttm,
  SUM(total_non_interest_exp) OVER (PARTITION BY ticker ORDER BY report_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS non_int_exp_ttm
FROM v_bank_base;



SELECT *
FROM v_bank_ttm ORDER BY revenue_ttm DESC
LIMIT 10;


/*
The TTM efficiency ratio analysis revealed several banks reporting negative values (e.g., MLVF -211%, EQBK -157%). 
This occurs when net revenue after provisions turns negative over the trailing four quarters, 
while non-interest expenses remain positive. In practice, CFOs would interpret these anomalies as signals of stress,
 often linked to outsized loan loss provisions or extraordinary charges. 
 For healthy banks, efficiency ratios typically remain between 50–60%; 
 the negative results highlight periods of financial strain where expenses outweighed revenue.
 */



WITH last_q AS (
  SELECT ticker, MAX(report_date) AS last_report
  FROM v_bank_base
  GROUP BY ticker
)
SELECT k.ticker, k.report_date, k.net_margin_pct, k.operating_margin_pct, k.efficiency_ratio_pct
FROM v_bank_income_kpis k
JOIN last_q l ON l.ticker = k.ticker AND l.last_report = k.report_date
ORDER BY k.net_margin_pct DESC
LIMIT 10;


WITH last_q AS (
  SELECT ticker, MAX(report_date) AS last_report
  FROM v_bank_base
  GROUP BY ticker
)
SELECT y.ticker, y.report_date, y.revenue, y.revenue_yoy_pct, y.net_income_yoy_pct
FROM v_bank_yoy y
JOIN last_q l ON l.ticker = y.ticker AND l.last_report = y.report_date
ORDER BY y.revenue_yoy_pct DESC
LIMIT 10;

WITH last_q AS (
  SELECT ticker, MAX(report_date) AS last_report
  FROM v_bank_base
  GROUP BY ticker
),
eff AS (
  SELECT
    t.ticker,
    t.report_date,
    ROUND( t.non_int_exp_ttm / NULLIF(t.net_rev_after_prov_ttm,0) * 100, 2 ) AS efficiency_ratio_ttm_pct
  FROM v_bank_ttm t
)
SELECT e.ticker, e.report_date, e.efficiency_ratio_ttm_pct
FROM eff e
JOIN last_q l ON l.ticker = e.ticker AND l.last_report = e.report_date
ORDER BY e.efficiency_ratio_ttm_pct ASC
LIMIT 10;





