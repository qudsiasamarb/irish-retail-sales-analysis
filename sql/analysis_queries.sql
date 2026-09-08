CREATE DATABASE irish_retail;

USE irish_retail;

SHOW DATABASES;

SELECT COUNT(*) AS total_rows
FROM rsm08_clean;

DESCRIBE rsm08_clean;

DROP TABLE IF EXISTS raw_rsm08;

CREATE TABLE raw_rsm08 (
    statistic_code VARCHAR(20),
    statistic_label TEXT,
    year_month1 VARCHAR(10),
    month_label VARCHAR(30),
    sector_code VARCHAR(20),
    sector_label TEXT,
    unit VARCHAR(50),
    value_raw VARCHAR(30)
);

DESCRIBE raw_rsm08;

SELECT COUNT(*) AS total_rows
FROM raw_rsm08;

DROP TABLE IF EXISTS raw_rsm07;

CREATE TABLE raw_rsm07 (
    statistic_code VARCHAR(20),
    statistic_label TEXT,
    year_month1 VARCHAR(10),
    month_label VARCHAR(30),
    sector_code VARCHAR(20),
    sector_label TEXT,
    unit VARCHAR(50),
    value_raw VARCHAR(30)
);

SELECT COUNT(*) AS total_rows
FROM raw_rsm07;

SELECT *
FROM raw_rsm08
LIMIT 5;

SELECT *
FROM raw_rsm07
LIMIT 5;

SELECT COUNT(*) AS missing_values
FROM raw_rsm08
WHERE value_raw IS NULL
   OR value_raw = '';
   
SELECT COUNT(*) AS missing_values
FROM raw_rsm07
WHERE value_raw IS NULL
   OR value_raw = '';
   
SELECT
    statistic_code,
    statistic_label,
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN value_raw IS NULL OR TRIM(value_raw) = '' THEN 1
            ELSE 0
        END
    ) AS missing_values
FROM raw_rsm08
GROUP BY statistic_code, statistic_label
ORDER BY statistic_code;

SELECT
    statistic_code,
    statistic_label,
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN value_raw IS NULL
              OR TRIM(value_raw) = ''
            THEN 1
            ELSE 0
        END
    ) AS missing_values
FROM raw_rsm07
GROUP BY statistic_code, statistic_label
ORDER BY statistic_code;

SELECT
    sector_code,
    sector_label,
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN value_raw IS NULL
              OR TRIM(value_raw) = ''
            THEN 1
            ELSE 0
        END
    ) AS missing_values
FROM raw_rsm07
GROUP BY sector_code, sector_label
ORDER BY missing_values DESC, sector_label;

DROP TABLE IF EXISTS clean_rsm08;

CREATE TABLE clean_rsm08 AS
SELECT
    TRIM(statistic_code) AS statistic_code,
    TRIM(statistic_label) AS statistic_label,
    CAST(year_month1 AS UNSIGNED) AS year_month1,
    TRIM(month_label) AS month_label,
    TRIM(sector_code) AS sector_code,
    TRIM(sector_label) AS sector_label,
    TRIM(unit) AS unit,
    CASE
        WHEN value_raw IS NULL OR TRIM(value_raw) = ''
        THEN NULL
        ELSE CAST(value_raw AS DECIMAL(12,2))
    END AS value
FROM raw_rsm08;

SELECT COUNT(*) AS total_rows
FROM clean_rsm08;

SELECT COUNT(*) AS missing_values
FROM clean_rsm08
WHERE value IS NULL;

DROP TABLE IF EXISTS clean_rsm07;

CREATE TABLE clean_rsm07 AS
SELECT
    TRIM(statistic_code) AS statistic_code,
    TRIM(statistic_label) AS statistic_label,
    CAST(year_month1 AS UNSIGNED) AS year_month1,
    TRIM(month_label) AS month_label,
    TRIM(sector_code) AS sector_code,
    TRIM(sector_label) AS sector_label,
    TRIM(unit) AS unit,
    CASE
        WHEN value_raw IS NULL OR TRIM(value_raw) = ''
        THEN NULL
        ELSE CAST(value_raw AS DECIMAL(12,2))
    END AS value
FROM raw_rsm07;

SELECT COUNT(*) AS total_rows
FROM clean_rsm07;

SELECT COUNT(*) AS missing_values
FROM clean_rsm07
WHERE value IS NULL;

CREATE TABLE dim_sector AS
SELECT DISTINCT
    sector_code,
    sector_label
FROM clean_rsm08;

SELECT COUNT(*) AS total_sectors
FROM dim_sector;

SELECT *
FROM dim_sector
ORDER BY sector_code;

CREATE TABLE dim_time AS
SELECT DISTINCT
    year_month1,
    month_label,
    FLOOR(year_month1 / 100) AS year,
    MOD(year_month1, 100) AS month_num,
    CONCAT(
        'Q',
        CEIL(MOD(year_month1, 100) / 3)
    ) AS quarter,
    STR_TO_DATE(
        CONCAT(year_month1, '01'),
        '%Y%m%d'
    ) AS month_start
FROM (
    SELECT year_month1, month_label
    FROM clean_rsm08

    UNION

    SELECT year_month1, month_label
    FROM clean_rsm07
) AS all_months;

SELECT COUNT(*) AS total_months
FROM dim_time;

SELECT
    MIN(month_start) AS first_month,
    MAX(month_start) AS latest_month
FROM dim_time;

CREATE TABLE dim_statistic AS
SELECT DISTINCT
    statistic_code,
    statistic_label,
    unit
FROM clean_rsm08;

SELECT *
FROM dim_statistic
ORDER BY statistic_code;

SELECT COUNT(*) AS total_statistics
FROM dim_statistic;

DROP TABLE IF EXISTS fact_retail_sales_index;

CREATE TABLE fact_retail_sales_index AS
SELECT
    statistic_code,
    year_month1,
    sector_code,
    value
FROM clean_rsm08;

SELECT COUNT(*) AS total_rows
FROM fact_retail_sales_index;

SELECT *
FROM fact_retail_sales_index
LIMIT 5;


CREATE TABLE fact_online_sales_share AS
SELECT
    year_month1,
    sector_code,
    value AS online_sales_pct
FROM clean_rsm07;

SELECT COUNT(*) AS total_rows
FROM fact_online_sales_share;

SELECT *
FROM fact_online_sales_share
LIMIT 5;

ALTER TABLE dim_sector
ADD COLUMN is_aggregate TINYINT;

SET SQL_SAFE_UPDATES = 0;

UPDATE dim_sector
SET is_aggregate =
    CASE
        WHEN sector_code LIKE 'X%'
          OR sector_code LIKE 'V%'
        THEN 1
        ELSE 0
    END;
    
SET SQL_SAFE_UPDATES = 1;

SELECT
    sector_code,
    sector_label,
    is_aggregate
FROM dim_sector
ORDER BY sector_code;

ALTER TABLE dim_sector
ADD COLUMN short_label VARCHAR(100);

SET SQL_SAFE_UPDATES = 0;

UPDATE dim_sector
SET short_label =
    CASE sector_code
        WHEN '45' THEN 'Motor trades'
        WHEN '4711' THEN 'Food-dominant stores'
        WHEN '4719' THEN 'Department stores'
        WHEN '4730' THEN 'Automotive fuel'
        WHEN '4752' THEN 'Hardware, paints & glass'
        WHEN '4759' THEN 'Furniture & lighting'
        WHEN '5630' THEN 'Bars'

        WHEN 'V3970' THEN 'All retail businesses'
        WHEN 'V3980' THEN 'Motor trades & automotive fuel'

        WHEN 'X1310' THEN 'Retail excl. motor trades & bars'
        WHEN 'X1320' THEN 'Retail excl. motor trades'
        WHEN 'X1330' THEN 'Retail excl. motor, fuel & bars'
        WHEN 'X1340' THEN 'Food retail'
        WHEN 'X1350' THEN 'Non-food retail'
        WHEN 'X1360' THEN 'Specialised food & beverages'
        WHEN 'X1370' THEN 'Household equipment'
        WHEN 'X1380' THEN 'Electrical goods'
        WHEN 'X1390' THEN 'Textiles, clothing & footwear'
        WHEN 'X1400' THEN 'Books, stationery & other goods'
        WHEN 'X1410' THEN 'Other retail sales'
        WHEN 'X1420' THEN 'Books, newspapers & stationery'
        WHEN 'X1430' THEN 'Pharma, medical & cosmetics'

        ELSE sector_label
    END;

SET SQL_SAFE_UPDATES = 1;
  
SELECT
    sector_code,
    short_label,
    is_aggregate
FROM dim_sector
ORDER BY sector_code;
    
DROP VIEW IF EXISTS vw_dashboard;

CREATE VIEW vw_dashboard AS
SELECT
    t.year_month1 AS year_month1,
    t.month_label,
    t.month_start,
    t.year,
    t.quarter,
    t.month_num,

    s.sector_code,
    s.short_label AS sector,
    s.is_aggregate,

    MAX(
        CASE
            WHEN f.statistic_code = 'RSM08C03'
            THEN f.value
        END
    ) AS value_index_adj,

    MAX(
        CASE
            WHEN f.statistic_code = 'RSM08C04'
            THEN f.value
        END
    ) AS volume_index_adj,

    MAX(
        CASE
            WHEN f.statistic_code = 'RSM08C07'
            THEN f.value
        END
    ) AS value_mom_pct,

    MAX(
        CASE
            WHEN f.statistic_code = 'RSM08C08'
            THEN f.value
        END
    ) AS value_yoy_pct,

    MAX(
        CASE
            WHEN f.statistic_code = 'RSM08C05'
            THEN f.value
        END
    ) AS volume_mom_pct,

    MAX(
        CASE
            WHEN f.statistic_code = 'RSM08C06'
            THEN f.value
        END
    ) AS volume_yoy_pct,

    MAX(o.online_sales_pct) AS online_sales_pct

FROM fact_retail_sales_index f

JOIN dim_sector s
    ON f.sector_code = s.sector_code

JOIN dim_time t
    ON f.year_month1 = t.year_month1

LEFT JOIN fact_online_sales_share o
    ON f.sector_code = o.sector_code
   AND f.year_month1 = o.year_month1

GROUP BY
    t.year_month1,
    t.month_label,
    t.month_start,
    t.year,
    t.quarter,
    t.month_num,
    s.sector_code,
    s.short_label,
    s.is_aggregate;
    
    
SELECT *
FROM vw_dashboard
LIMIT 10;

SELECT COUNT(*) AS total_dashboard_rows
FROM vw_dashboard; 

#Which individual Irish retail sectors performed best and worst in the latest month based on YoY volume growth?

SELECT
    sector,
    month_label,
    volume_yoy_pct
FROM vw_dashboard
WHERE is_aggregate = 0
  AND year_month1 = (
      SELECT MAX(year_month1)
      FROM vw_dashboard
  )
ORDER BY volume_yoy_pct DESC;

#How have Irish retail sales value and volume changed over time?
SELECT
    month_start,
    month_label,
    value_index_adj,
    volume_index_adj
FROM vw_dashboard
WHERE sector_code = 'V3970'
ORDER BY month_start;

# strongest and weakest sectors over the latest 12 months.

SELECT
    sector,
    ROUND(AVG(volume_yoy_pct), 2) AS avg_yoy_volume_growth_pct,
    ROUND(MIN(volume_yoy_pct), 2) AS worst_month_pct,
    ROUND(MAX(volume_yoy_pct), 2) AS best_month_pct,
    COUNT(volume_yoy_pct) AS months_counted
FROM vw_dashboard
WHERE is_aggregate = 0
  AND month_start >= DATE_SUB(
        (SELECT MAX(month_start) FROM vw_dashboard),
        INTERVAL 11 MONTH
      )
GROUP BY sector
ORDER BY avg_yoy_volume_growth_pct DESC;

# Which Irish retail sectors have increased or decreased their share of online sales compared with the same month last year?
SELECT
    latest.sector,
    latest.online_sales_pct AS online_pct_latest,
    previous.online_sales_pct AS online_pct_year_ago,

    ROUND(
        latest.online_sales_pct - previous.online_sales_pct,
        2
    ) AS percentage_point_change

FROM vw_dashboard latest

JOIN vw_dashboard previous
    ON latest.sector_code = previous.sector_code
    AND previous.month_start =
        DATE_SUB(latest.month_start, INTERVAL 1 YEAR)

WHERE latest.month_start = (
    SELECT MAX(month_start)
    FROM vw_dashboard
)

AND latest.online_sales_pct IS NOT NULL
AND previous.online_sales_pct IS NOT NULL

ORDER BY percentage_point_change DESC;

# Which months tend to have the strongest retail activity in Ireland?

SELECT
    t.month_num,
    MONTHNAME(t.month_start) AS month_name,
    ROUND(AVG(f.value), 2) AS avg_value_index_unadjusted,
    COUNT(f.value) AS years_counted

FROM fact_retail_sales_index f

JOIN dim_time t
    ON f.year_month1 = t.year_month1

WHERE f.sector_code = 'V3970'
  AND f.statistic_code = 'RSM08C01'
  AND t.year BETWEEN 2021 AND 2025

GROUP BY
    t.month_num,
    MONTHNAME(t.month_start)

ORDER BY t.month_num;

# Which retail sectors are most unstable month-to-month, and which are relatively stable?

SELECT
    s.short_label AS sector,

    ROUND(AVG(f.value), 2) AS avg_mom_change_pct,

    ROUND(
        STDDEV_POP(f.value),
        2
    ) AS mom_volatility_stddev

FROM fact_retail_sales_index f

JOIN dim_sector s
    ON f.sector_code = s.sector_code

WHERE f.statistic_code = 'RSM08C05'
  AND s.is_aggregate = 0
  AND f.value IS NOT NULL

GROUP BY
    s.short_label

ORDER BY
    mom_volatility_stddev DESC;
    
SELECT *
FROM vw_dashboard
ORDER BY month_start, sector;

SELECT
    t.month_num,
    MONTHNAME(t.month_start) AS month_name,
    ROUND(AVG(f.value), 2) AS avg_value_index_unadjusted
FROM fact_retail_sales_index f
JOIN dim_time t
    ON f.year_month1 = t.year_month1
WHERE f.sector_code = 'V3970'
  AND f.statistic_code = 'RSM08C01'
  AND t.year BETWEEN 2021 AND 2025
GROUP BY
    t.month_num,
    MONTHNAME(t.month_start)
ORDER BY t.month_num;
