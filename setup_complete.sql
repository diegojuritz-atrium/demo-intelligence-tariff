-- ============================================================================
-- TARIFF INTELLIGENCE DEMO - COMPLETE SETUP SCRIPT
-- ============================================================================
-- This script creates ALL objects in DJURITZ.TARIFF from scratch.
-- Run sections in order. Some sections require ACCOUNTADMIN.
--
-- Objects created:
--   8 RAW tables (Bronze)    + synthetic data inserts
--   8 STG views  (Staging)
--   5 SLV tables (Silver)    + data via CTAS
--   7 GLD tables (Gold)      + data via CTAS
--   1 Semantic View
--   1 API Integration        (requires ACCOUNTADMIN)
--   2 Git Repositories
--   1 dbt Project            (deployed via UI)
--   2 Tasks
--   1 Cortex Agent
--   Grants
-- ============================================================================


-- ============================================================================
-- SECTION 0: SCHEMA SETUP
-- ============================================================================

USE ROLE DATA_ENGINEERING;
USE WAREHOUSE DE_WH;
USE DATABASE DJURITZ;
CREATE SCHEMA IF NOT EXISTS DJURITZ.TARIFF;
USE SCHEMA DJURITZ.TARIFF;


-- ============================================================================
-- SECTION 1: BRONZE LAYER - RAW TABLES + DATA
-- ============================================================================

-- 1.1 RAW_COUNTRIES (50 rows)
CREATE OR REPLACE TABLE RAW_COUNTRIES (
    COUNTRY_CODE VARCHAR(3) NOT NULL,
    COUNTRY_NAME VARCHAR(100) NOT NULL,
    REGION VARCHAR(50),
    CONTINENT VARCHAR(50),
    CONSTRAINT PK_RAW_COUNTRIES PRIMARY KEY (COUNTRY_CODE)
);

INSERT INTO RAW_COUNTRIES VALUES
('USA','United States','North America','Americas'),('CAN','Canada','North America','Americas'),('MEX','Mexico','Central America','Americas'),('BRA','Brazil','South America','Americas'),('ARG','Argentina','South America','Americas'),('CHL','Chile','South America','Americas'),('COL','Colombia','South America','Americas'),('PER','Peru','South America','Americas'),('CRI','Costa Rica','Central America','Americas'),('PAN','Panama','Central America','Americas'),
('GBR','United Kingdom','Western Europe','Europe'),('DEU','Germany','Western Europe','Europe'),('FRA','France','Western Europe','Europe'),('ITA','Italy','Southern Europe','Europe'),('ESP','Spain','Southern Europe','Europe'),('NLD','Netherlands','Western Europe','Europe'),('BEL','Belgium','Western Europe','Europe'),('CHE','Switzerland','Western Europe','Europe'),('SWE','Sweden','Northern Europe','Europe'),('NOR','Norway','Northern Europe','Europe'),('POL','Poland','Eastern Europe','Europe'),('CZE','Czech Republic','Eastern Europe','Europe'),('ROU','Romania','Eastern Europe','Europe'),('HUN','Hungary','Eastern Europe','Europe'),('PRT','Portugal','Southern Europe','Europe'),
('CHN','China','East Asia','Asia'),('JPN','Japan','East Asia','Asia'),('KOR','South Korea','East Asia','Asia'),('TWN','Taiwan','East Asia','Asia'),('HKG','Hong Kong','East Asia','Asia'),('IND','India','South Asia','Asia'),('THA','Thailand','Southeast Asia','Asia'),('VNM','Vietnam','Southeast Asia','Asia'),('MYS','Malaysia','Southeast Asia','Asia'),('SGP','Singapore','Southeast Asia','Asia'),('IDN','Indonesia','Southeast Asia','Asia'),('PHL','Philippines','Southeast Asia','Asia'),('BGD','Bangladesh','South Asia','Asia'),('PAK','Pakistan','South Asia','Asia'),
('AUS','Australia','Oceania','Oceania'),('NZL','New Zealand','Oceania','Oceania'),
('SAU','Saudi Arabia','Middle East','Asia'),('ARE','United Arab Emirates','Middle East','Asia'),('ISR','Israel','Middle East','Asia'),('TUR','Turkey','Middle East','Europe'),
('ZAF','South Africa','Southern Africa','Africa'),('EGY','Egypt','North Africa','Africa'),('NGA','Nigeria','West Africa','Africa'),('KEN','Kenya','East Africa','Africa'),('MAR','Morocco','North Africa','Africa');


-- 1.2 RAW_PRODUCT_CATALOG (200 rows)
CREATE OR REPLACE TABLE RAW_PRODUCT_CATALOG (
    PRODUCT_ID INT NOT NULL,
    PRODUCT_NAME VARCHAR(200) NOT NULL,
    PRODUCT_CATEGORY VARCHAR(100),
    SUB_CATEGORY VARCHAR(100),
    MSRP DECIMAL(10,2),
    WEIGHT_KG DECIMAL(8,2),
    LAUNCH_DATE DATE,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CONSTRAINT PK_RAW_PRODUCT_CATALOG PRIMARY KEY (PRODUCT_ID)
);

INSERT INTO RAW_PRODUCT_CATALOG
WITH categories AS (
    SELECT column1 AS cat, column2 AS sub_cat, column3::FLOAT AS base_price, column4::FLOAT AS base_weight FROM VALUES
    ('Electronics','Smartphones',699,0.18),('Electronics','Laptops',1199,1.8),('Electronics','Tablets',499,0.45),('Electronics','Monitors',349,4.5),('Electronics','Headphones',199,0.25),
    ('Electronics','Cameras',599,0.5),('Electronics','Smartwatches',299,0.05),('Electronics','Speakers',149,1.2),('Electronics','Routers',89,0.3),('Electronics','Cables',19,0.1),
    ('Appliances','Refrigerators',1299,70),('Appliances','Washing Machines',899,65),('Appliances','Dishwashers',749,50),('Appliances','Microwaves',199,15),('Appliances','Air Conditioners',599,30),
    ('Industrial','CNC Machines',25000,500),('Industrial','Compressors',3500,80),('Industrial','Generators',5000,150),('Industrial','Welding Equipment',2000,25),('Industrial','Conveyors',8000,200),
    ('Automotive','Brake Systems',450,8),('Automotive','Engine Parts',800,15),('Automotive','Suspension',350,12),('Automotive','Lighting Systems',120,2),('Automotive','Sensors',85,0.2)
),
variants AS (SELECT SEQ4() + 1 AS variant_num FROM TABLE(GENERATOR(ROWCOUNT => 8))),
expanded AS (
    SELECT c.cat, c.sub_cat, c.base_price, c.base_weight, v.variant_num,
           ROW_NUMBER() OVER (ORDER BY c.cat, c.sub_cat, v.variant_num) AS product_id
    FROM categories c CROSS JOIN variants v
)
SELECT product_id, cat || ' ' || sub_cat || ' Model-' || LPAD(variant_num::VARCHAR, 3, '0'), cat, sub_cat,
    ROUND(base_price * (0.7 + ABS(HASH(product_id, 1)) / POWER(2,62) * 0.6), 2),
    ROUND(base_weight * (0.8 + ABS(HASH(product_id, 2)) / POWER(2,62) * 0.4), 2),
    DATEADD('day', -(ABS(HASH(product_id, 3)) % 1825), '2026-03-19'::DATE),
    IFF(ABS(HASH(product_id, 4)) % 100 > 10, TRUE, FALSE)
FROM expanded WHERE product_id <= 200;


-- 1.3 RAW_PARTS (1,000 rows)
CREATE OR REPLACE TABLE RAW_PARTS (
    PART_ID INT NOT NULL,
    PART_NUMBER VARCHAR(30) NOT NULL,
    PART_NAME VARCHAR(200) NOT NULL,
    PART_CATEGORY VARCHAR(100),
    UNIT_OF_MEASURE VARCHAR(20),
    WEIGHT_KG DECIMAL(8,4),
    CONSTRAINT PK_RAW_PARTS PRIMARY KEY (PART_ID)
);

INSERT INTO RAW_PARTS
WITH part_cats AS (
    SELECT column1 AS pcat, column2 AS uom, column3::FLOAT AS avg_wt FROM VALUES
    ('Semiconductors','EA',0.002),('Displays','EA',0.15),('Batteries','EA',0.08),('Motors','EA',0.5),('PCB Boards','EA',0.03),
    ('Sensors','EA',0.01),('Connectors','EA',0.005),('Housings','EA',0.3),('Raw Materials','KG',1.0),('Capacitors','EA',0.001),
    ('Resistors','EA',0.0005),('Transformers','EA',0.2),('Fans','EA',0.15),('Heat Sinks','EA',0.1),('Cables','M',0.05),
    ('Bearings','EA',0.08),('Gears','EA',0.12),('Valves','EA',0.25),('Pumps','EA',0.6),('Filters','EA',0.04)
),
seq AS (SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 50))),
expanded AS (
    SELECT p.pcat, p.uom, p.avg_wt, s.n,
           ROW_NUMBER() OVER (ORDER BY p.pcat, s.n) AS part_id
    FROM part_cats p CROSS JOIN seq s
)
SELECT part_id, UPPER(LEFT(pcat, 3)) || '-' || LPAD(part_id::VARCHAR, 5, '0'),
    pcat || ' Component ' || LPAD(n::VARCHAR, 3, '0'), pcat, uom,
    ROUND(avg_wt * (0.5 + ABS(HASH(part_id, 10)) / POWER(2,62) * 1.5), 4)
FROM expanded WHERE part_id <= 1000;


-- 1.4 RAW_PRODUCT_PARTS - BOM (5,000 rows)
CREATE OR REPLACE TABLE RAW_PRODUCT_PARTS (
    PRODUCT_PART_ID INT NOT NULL,
    PRODUCT_ID INT NOT NULL,
    PART_ID INT NOT NULL,
    QUANTITY_REQUIRED INT NOT NULL DEFAULT 1,
    IS_CRITICAL BOOLEAN DEFAULT FALSE,
    CONSTRAINT PK_RAW_PRODUCT_PARTS PRIMARY KEY (PRODUCT_PART_ID)
);

INSERT INTO RAW_PRODUCT_PARTS
WITH nums AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 30))),
product_ids AS (SELECT PRODUCT_ID FROM RAW_PRODUCT_CATALOG),
deduped AS (
    SELECT PRODUCT_ID, 1 + ABS(HASH(PRODUCT_ID, n)) % 1000 AS part_id, MIN(n) AS seq_num
    FROM product_ids CROSS JOIN nums GROUP BY PRODUCT_ID, part_id
)
SELECT ROW_NUMBER() OVER (ORDER BY PRODUCT_ID, part_id), PRODUCT_ID, part_id,
    1 + ABS(HASH(PRODUCT_ID, part_id, 1)) % 10,
    IFF(ABS(HASH(PRODUCT_ID, part_id, 2)) % 100 < 30, TRUE, FALSE)
FROM deduped LIMIT 5000;


-- 1.5 RAW_SUPPLIERS (500 rows across 25 countries)
CREATE OR REPLACE TABLE RAW_SUPPLIERS (
    SUPPLIER_ID INT NOT NULL,
    SUPPLIER_NAME VARCHAR(200) NOT NULL,
    COUNTRY_CODE VARCHAR(3) NOT NULL,
    CITY VARCHAR(100),
    SUPPLIER_RATING DECIMAL(3,1),
    LEAD_TIME_DAYS INT,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CONSTRAINT PK_RAW_SUPPLIERS PRIMARY KEY (SUPPLIER_ID)
);

INSERT INTO RAW_SUPPLIERS
WITH countries_weighted AS (
    SELECT column1 AS cc, column2 AS city_name FROM VALUES
    ('CHN','Shanghai'),('CHN','Shenzhen'),('CHN','Guangzhou'),('CHN','Beijing'),('CHN','Dongguan'),
    ('TWN','Taipei'),('TWN','Hsinchu'),('KOR','Seoul'),('KOR','Busan'),('JPN','Tokyo'),
    ('JPN','Osaka'),('DEU','Munich'),('DEU','Stuttgart'),('IND','Mumbai'),('IND','Bangalore'),
    ('IND','Chennai'),('VNM','Ho Chi Minh'),('VNM','Hanoi'),('THA','Bangkok'),('MYS','Penang'),
    ('MYS','Kuala Lumpur'),('MEX','Monterrey'),('MEX','Guadalajara'),('BRA','Sao Paulo'),('IDN','Jakarta'),
    ('PHL','Manila'),('SGP','Singapore'),('GBR','Birmingham'),('ITA','Milan'),('CZE','Prague'),
    ('POL','Warsaw'),('HUN','Budapest'),('TUR','Istanbul'),('MAR','Casablanca'),('ZAF','Johannesburg'),
    ('BGD','Dhaka'),('PAK','Karachi'),('USA','Detroit'),('USA','Houston'),('CAN','Toronto')
),
prefixes AS (
    SELECT column1 AS pfx FROM VALUES
    ('Global'),('Pacific'),('Asia'),('Euro'),('Trans'),('United'),('Prime'),('Alpha'),('Apex'),('Star'),('Nova'),('Vertex'),('Omega')
),
base AS (
    SELECT ROW_NUMBER() OVER (ORDER BY c.cc, c.city_name, p.pfx) AS rn, c.cc, c.city_name, p.pfx
    FROM countries_weighted c CROSS JOIN prefixes p
)
SELECT rn, pfx || ' ' || city_name || ' Supply ' || LPAD(rn::VARCHAR, 3, '0'), cc, city_name,
    ROUND(1.0 + ABS(HASH(rn, 20)) / POWER(2,62) * 4.0, 1),
    5 + ABS(HASH(rn, 21)) % 55,
    IFF(ABS(HASH(rn, 22)) % 100 > 8, TRUE, FALSE)
FROM base WHERE rn <= 500;


-- 1.6 RAW_PARTS_SUPPLIER (10,000 rows)
CREATE OR REPLACE TABLE RAW_PARTS_SUPPLIER (
    PARTS_SUPPLIER_ID INT NOT NULL,
    PART_ID INT NOT NULL,
    SUPPLIER_ID INT NOT NULL,
    UNIT_COST DECIMAL(10,4) NOT NULL,
    CURRENCY VARCHAR(3) DEFAULT 'USD',
    MIN_ORDER_QTY INT DEFAULT 1,
    IS_PREFERRED BOOLEAN DEFAULT FALSE,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CONSTRAINT PK_RAW_PARTS_SUPPLIER PRIMARY KEY (PARTS_SUPPLIER_ID)
);

INSERT INTO RAW_PARTS_SUPPLIER
WITH nums AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 15))),
part_ids AS (SELECT PART_ID, WEIGHT_KG FROM RAW_PARTS),
deduped AS (
    SELECT PART_ID, WEIGHT_KG, 1 + ABS(HASH(PART_ID, n)) % 500 AS supplier_id, MIN(n) AS seq_num
    FROM part_ids CROSS JOIN nums GROUP BY PART_ID, WEIGHT_KG, supplier_id
)
SELECT ROW_NUMBER() OVER (ORDER BY PART_ID, supplier_id), PART_ID, supplier_id,
    ROUND(GREATEST(0.01, (WEIGHT_KG * 10 + 0.5) * (0.5 + ABS(HASH(PART_ID, supplier_id, 30)) / POWER(2,62) * 1.5)), 4),
    'USD', GREATEST(1, 10 * (1 + ABS(HASH(PART_ID, supplier_id, 31)) % 50)),
    IFF(seq_num = 0, TRUE, FALSE),
    IFF(ABS(HASH(PART_ID, supplier_id, 32)) % 100 > 5, TRUE, FALSE)
FROM deduped LIMIT 10000;


-- 1.7 RAW_MARKET_TARIFFS (30,000 rows)
CREATE OR REPLACE TABLE RAW_MARKET_TARIFFS (
    TARIFF_ID INT NOT NULL,
    SOURCE_COUNTRY_CODE VARCHAR(3) NOT NULL,
    DESTINATION_COUNTRY_CODE VARCHAR(3) NOT NULL,
    HS_CODE VARCHAR(10),
    PRODUCT_CATEGORY VARCHAR(100),
    TARIFF_RATE_PCT DECIMAL(6,2) NOT NULL,
    EFFECTIVE_DATE DATE NOT NULL,
    END_DATE DATE,
    TARIFF_TYPE VARCHAR(50),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CONSTRAINT PK_RAW_MARKET_TARIFFS PRIMARY KEY (TARIFF_ID)
);

INSERT INTO RAW_MARKET_TARIFFS
WITH source_countries AS (SELECT COUNTRY_CODE FROM RAW_COUNTRIES WHERE COUNTRY_CODE != 'USA'),
hs_codes AS (
    SELECT column1 AS hs, column2 AS pcat FROM VALUES
    ('8471.30','Electronics'),('8471.41','Electronics'),('8517.12','Electronics'),('8528.72','Electronics'),('8518.30','Electronics'),
    ('8525.80','Electronics'),('9102.12','Electronics'),('8518.22','Electronics'),('8517.62','Electronics'),('8544.42','Electronics'),
    ('8418.10','Appliances'),('8450.11','Appliances'),('8422.11','Appliances'),('8516.50','Appliances'),('8415.10','Appliances'),
    ('8456.10','Industrial'),('8414.80','Industrial'),('8502.20','Industrial'),('8515.21','Industrial'),('8428.33','Industrial'),
    ('8708.30','Automotive'),('8409.91','Automotive'),('8708.80','Automotive'),('8512.20','Automotive'),('9031.80','Automotive')
),
date_offsets AS (SELECT SEQ4() AS d_off FROM TABLE(GENERATOR(ROWCOUNT => 25)))
SELECT ROW_NUMBER() OVER (ORDER BY sc.COUNTRY_CODE, h.hs, d.d_off), sc.COUNTRY_CODE, 'USA', h.hs, h.pcat,
    ROUND(GREATEST(0.5, ABS(HASH(sc.COUNTRY_CODE, h.hs, d.d_off, 40)) / POWER(2,62) * 45.0), 2),
    DATEADD('month', -d.d_off * 3, DATEADD('day', -(ABS(HASH(sc.COUNTRY_CODE, h.hs, 41)) % 180), '2026-03-19'::DATE)),
    CASE WHEN d.d_off > 0 THEN DATEADD('month', -(d.d_off - 1) * 3, DATEADD('day', -(ABS(HASH(sc.COUNTRY_CODE, h.hs, 41)) % 180), '2026-03-19'::DATE)) ELSE NULL END,
    CASE ABS(HASH(sc.COUNTRY_CODE, h.hs, d.d_off, 42)) % 6
        WHEN 0 THEN 'Ad Valorem' WHEN 1 THEN 'Specific' WHEN 2 THEN 'Mixed'
        WHEN 3 THEN 'Anti-Dumping' WHEN 4 THEN 'Countervailing' ELSE 'Most Favored Nation' END,
    IFF(d.d_off = 0, TRUE, FALSE)
FROM source_countries sc CROSS JOIN hs_codes h CROSS JOIN date_offsets d
LIMIT 30000;


-- 1.8 RAW_ROUTES (3,250 rows)
CREATE OR REPLACE TABLE RAW_ROUTES (
    ROUTE_ID INT NOT NULL,
    ORIGIN_COUNTRY_CODE VARCHAR(3) NOT NULL,
    DESTINATION_COUNTRY_CODE VARCHAR(3) NOT NULL,
    TRANSPORT_MODE VARCHAR(30) NOT NULL,
    TRANSIT_DAYS INT,
    COST_PER_KG DECIMAL(8,4),
    COST_PER_UNIT DECIMAL(8,2),
    RELIABILITY_SCORE DECIMAL(3,1),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CONSTRAINT PK_RAW_ROUTES PRIMARY KEY (ROUTE_ID)
);

INSERT INTO RAW_ROUTES
WITH origin_countries AS (SELECT COUNTRY_CODE, CONTINENT FROM RAW_COUNTRIES WHERE COUNTRY_CODE != 'USA'),
modes AS (
    SELECT column1 AS mode_name, column2::INT AS base_days, column3::FLOAT AS base_cost_kg, column4::FLOAT AS base_cost_unit FROM VALUES
    ('Ocean Freight',25,0.15,5.0),('Air Freight',3,2.50,25.0),('Rail',15,0.30,8.0),
    ('Truck',5,0.50,12.0),('Multimodal',12,0.40,10.0),('Express Air',1,5.00,50.0),('Bulk Shipping',30,0.08,3.0)
),
carriers AS (SELECT column1 AS carrier_suffix FROM VALUES ('Route A'),('Route B'),('Route C'),('Route D'),('Route E'),('Route F'),('Route G'),('Route H'),('Route I'),('Route J'))
SELECT ROW_NUMBER() OVER (ORDER BY o.COUNTRY_CODE, m.mode_name, c.carrier_suffix),
    o.COUNTRY_CODE, 'USA', m.mode_name || ' - ' || c.carrier_suffix,
    GREATEST(1, m.base_days + CASE o.CONTINENT WHEN 'Asia' THEN 5 WHEN 'Europe' THEN 3 WHEN 'Americas' THEN -2 WHEN 'Africa' THEN 8 WHEN 'Oceania' THEN 6 ELSE 0 END
        + (ABS(HASH(o.COUNTRY_CODE, m.mode_name, c.carrier_suffix, 50)) % 7 - 3)),
    ROUND(m.base_cost_kg * (0.6 + ABS(HASH(o.COUNTRY_CODE, m.mode_name, c.carrier_suffix, 51)) / POWER(2,62) * 0.8), 4),
    ROUND(m.base_cost_unit * (0.6 + ABS(HASH(o.COUNTRY_CODE, m.mode_name, c.carrier_suffix, 52)) / POWER(2,62) * 0.8), 2),
    ROUND(GREATEST(1.0, LEAST(5.0, 3.0 + ABS(HASH(o.COUNTRY_CODE, m.mode_name, c.carrier_suffix, 53)) / POWER(2,62) * 2.0 - 1.0)), 1),
    IFF(ABS(HASH(o.COUNTRY_CODE, m.mode_name, c.carrier_suffix, 54)) % 100 > 8, TRUE, FALSE)
FROM origin_countries o CROSS JOIN modes m CROSS JOIN carriers c
LIMIT 3250;


-- ============================================================================
-- SECTION 2: STAGING LAYER - VIEWS (created by dbt, but included for completeness)
-- ============================================================================

CREATE OR REPLACE VIEW STG_COUNTRIES AS
SELECT country_code, country_name, region, continent
FROM DJURITZ.TARIFF.RAW_COUNTRIES;

CREATE OR REPLACE VIEW STG_PRODUCT_CATALOG AS
SELECT product_id, product_name, product_category, sub_category, msrp, weight_kg, launch_date, is_active
FROM DJURITZ.TARIFF.RAW_PRODUCT_CATALOG;

CREATE OR REPLACE VIEW STG_PARTS AS
SELECT part_id, part_number, part_name, part_category, unit_of_measure, weight_kg
FROM DJURITZ.TARIFF.RAW_PARTS;

CREATE OR REPLACE VIEW STG_PRODUCT_PARTS AS
SELECT product_part_id, product_id, part_id, quantity_required, is_critical
FROM DJURITZ.TARIFF.RAW_PRODUCT_PARTS;

CREATE OR REPLACE VIEW STG_SUPPLIERS AS
SELECT supplier_id, TRIM(supplier_name) AS supplier_name, country_code, TRIM(city) AS city, supplier_rating, lead_time_days, is_active
FROM DJURITZ.TARIFF.RAW_SUPPLIERS;

CREATE OR REPLACE VIEW STG_PARTS_SUPPLIER AS
SELECT parts_supplier_id, part_id, supplier_id, unit_cost, currency, min_order_qty, is_preferred, is_active
FROM DJURITZ.TARIFF.RAW_PARTS_SUPPLIER;

CREATE OR REPLACE VIEW STG_MARKET_TARIFFS AS
SELECT tariff_id, source_country_code, destination_country_code, hs_code, product_category, tariff_rate_pct, effective_date, end_date, tariff_type, is_active
FROM DJURITZ.TARIFF.RAW_MARKET_TARIFFS;

CREATE OR REPLACE VIEW STG_ROUTES AS
SELECT route_id, origin_country_code, destination_country_code, transport_mode, transit_days, cost_per_kg, cost_per_unit, reliability_score, is_active
FROM DJURITZ.TARIFF.RAW_ROUTES;


-- ============================================================================
-- SECTION 3: SILVER LAYER - ENRICHED TABLES (created by dbt, but included for completeness)
-- ============================================================================

CREATE OR REPLACE TABLE SLV_SUPPLIERS AS
SELECT s.supplier_id, s.supplier_name, s.country_code,
    c.country_name AS supplier_country, c.region AS supplier_region, c.continent AS supplier_continent,
    s.city AS supplier_city, s.supplier_rating, s.lead_time_days, s.is_active
FROM STG_SUPPLIERS s JOIN STG_COUNTRIES c ON s.country_code = c.country_code;

CREATE OR REPLACE TABLE SLV_PARTS_COSTED AS
SELECT ps.parts_supplier_id, ps.part_id, p.part_number, p.part_name, p.part_category,
    p.weight_kg AS part_weight_kg, ps.supplier_id, s.supplier_name,
    s.country_code AS supplier_country_code, c.country_name AS supplier_country,
    c.region AS supplier_region, s.supplier_rating, s.lead_time_days,
    ps.unit_cost, ps.currency, ps.min_order_qty, ps.is_preferred,
    ps.is_active AS supplier_part_active, s.is_active AS supplier_active
FROM STG_PARTS_SUPPLIER ps
JOIN STG_PARTS p ON ps.part_id = p.part_id
JOIN STG_SUPPLIERS s ON ps.supplier_id = s.supplier_id
JOIN STG_COUNTRIES c ON s.country_code = c.country_code;

CREATE OR REPLACE TABLE SLV_PRODUCT_BOM AS
SELECT pp.product_part_id, pp.product_id, pc.product_name, pc.product_category, pc.sub_category,
    pp.part_id, p.part_number, p.part_name, p.part_category, p.unit_of_measure,
    p.weight_kg AS part_weight_kg, pp.quantity_required, pp.is_critical,
    ROUND(p.weight_kg * pp.quantity_required, 4) AS total_part_weight_kg
FROM STG_PRODUCT_PARTS pp
JOIN STG_PRODUCT_CATALOG pc ON pp.product_id = pc.product_id
JOIN STG_PARTS p ON pp.part_id = p.part_id;

CREATE OR REPLACE TABLE SLV_ACTIVE_TARIFFS AS
SELECT t.tariff_id, t.source_country_code, sc.country_name AS source_country,
    sc.region AS source_region, sc.continent AS source_continent,
    t.destination_country_code, t.hs_code, t.product_category,
    t.tariff_rate_pct, t.effective_date, t.end_date, t.tariff_type, t.is_active,
    CASE WHEN t.tariff_rate_pct = 0 THEN 'Zero' WHEN t.tariff_rate_pct < 5 THEN 'Low'
         WHEN t.tariff_rate_pct < 15 THEN 'Medium' WHEN t.tariff_rate_pct < 25 THEN 'High' ELSE 'Very High' END AS tariff_band
FROM STG_MARKET_TARIFFS t JOIN STG_COUNTRIES sc ON t.source_country_code = sc.country_code;

CREATE OR REPLACE TABLE SLV_SHIPPING_ROUTES AS
SELECT r.route_id, r.origin_country_code, oc.country_name AS origin_country,
    oc.region AS origin_region, oc.continent AS origin_continent,
    r.destination_country_code, r.transport_mode, r.transit_days,
    r.cost_per_kg, r.cost_per_unit, r.reliability_score, r.is_active,
    CASE WHEN r.transit_days <= 3 THEN 'Express' WHEN r.transit_days <= 10 THEN 'Standard'
         WHEN r.transit_days <= 20 THEN 'Economy' ELSE 'Slow' END AS speed_tier
FROM STG_ROUTES r JOIN STG_COUNTRIES oc ON r.origin_country_code = oc.country_code;


-- ============================================================================
-- SECTION 4: GOLD LAYER - STAR SCHEMA (created by dbt, but included for completeness)
-- ============================================================================

-- Dimensions
CREATE OR REPLACE TABLE GLD_DIM_DATE AS
WITH date_spine AS (SELECT DATEADD('day', SEQ4(), '2019-01-01'::DATE) AS date_value FROM TABLE(GENERATOR(ROWCOUNT => 2800)))
SELECT TO_NUMBER(TO_CHAR(date_value, 'YYYYMMDD')) AS date_key, date_value AS full_date,
    YEAR(date_value) AS year_num, QUARTER(date_value) AS quarter_num,
    MONTH(date_value) AS month_num, MONTHNAME(date_value) AS month_name,
    DAYOFWEEK(date_value) AS day_of_week, DAYNAME(date_value) AS day_name,
    DAYOFYEAR(date_value) AS day_of_year, WEEKOFYEAR(date_value) AS week_of_year,
    IFF(DAYOFWEEK(date_value) IN (0, 6), TRUE, FALSE) AS is_weekend,
    'Q' || QUARTER(date_value) || ' ' || YEAR(date_value) AS quarter_label,
    MONTHNAME(date_value) || ' ' || YEAR(date_value) AS month_label
FROM date_spine;

CREATE OR REPLACE TABLE GLD_DIM_COUNTRY AS
SELECT ROW_NUMBER() OVER (ORDER BY country_code) AS country_key,
    country_code, country_name, region, continent
FROM STG_COUNTRIES;

CREATE OR REPLACE TABLE GLD_DIM_PRODUCT AS
SELECT product_id AS product_key, product_id, product_name, product_category,
    sub_category, msrp, weight_kg, launch_date, is_active
FROM STG_PRODUCT_CATALOG;

CREATE OR REPLACE TABLE GLD_DIM_PART AS
SELECT part_id AS part_key, part_id, part_number, part_name, part_category, unit_of_measure, weight_kg
FROM STG_PARTS;

CREATE OR REPLACE TABLE GLD_DIM_SUPPLIER AS
SELECT s.supplier_id AS supplier_key, s.supplier_id, s.supplier_name,
    s.country_code AS supplier_country_code, c.country_name AS supplier_country,
    c.region AS supplier_region, c.continent AS supplier_continent,
    s.supplier_city, s.supplier_rating, s.lead_time_days, s.is_active
FROM SLV_SUPPLIERS s JOIN GLD_DIM_COUNTRY c ON s.country_code = c.country_code;

-- Facts
CREATE OR REPLACE TABLE GLD_FACT_PROCUREMENT AS
WITH current_tariffs AS (
    SELECT source_country_code, product_category, tariff_rate_pct, tariff_type, tariff_band
    FROM (
        SELECT source_country_code, product_category, tariff_rate_pct, tariff_type, tariff_band,
               ROW_NUMBER() OVER (PARTITION BY source_country_code, product_category ORDER BY effective_date DESC) AS rn
        FROM SLV_ACTIVE_TARIFFS WHERE is_active = TRUE
    ) WHERE rn = 1
),
cheapest_routes AS (
    SELECT origin_country_code, transport_mode, cost_per_kg, cost_per_unit, transit_days, reliability_score, speed_tier
    FROM (
        SELECT origin_country_code, transport_mode, cost_per_kg, cost_per_unit, transit_days, reliability_score, speed_tier,
               ROW_NUMBER() OVER (PARTITION BY origin_country_code ORDER BY cost_per_kg ASC) AS rn
        FROM SLV_SHIPPING_ROUTES WHERE is_active = TRUE
    ) WHERE rn = 1
)
SELECT
    ROW_NUMBER() OVER (ORDER BY bom.product_id, bom.part_id, pc.supplier_id) AS procurement_key,
    dp.product_key, dpart.part_key, ds.supplier_key,
    dc.country_key AS supplier_country_key,
    bom.quantity_required, bom.is_critical, pc.unit_cost,
    ROUND(pc.unit_cost * bom.quantity_required, 4) AS total_part_cost,
    COALESCE(ct.tariff_rate_pct, 0) AS tariff_rate_pct,
    COALESCE(ct.tariff_type, 'None') AS tariff_type,
    ROUND(pc.unit_cost * bom.quantity_required * COALESCE(ct.tariff_rate_pct, 0) / 100, 4) AS tariff_cost,
    COALESCE(cr.cost_per_kg, 0) AS shipping_cost_per_kg,
    COALESCE(cr.cost_per_unit, 0) AS shipping_cost_per_unit,
    ROUND(COALESCE(cr.cost_per_kg * bom.total_part_weight_kg, 0) + COALESCE(cr.cost_per_unit * bom.quantity_required, 0), 4) AS total_shipping_cost,
    ROUND(pc.unit_cost * bom.quantity_required
          + pc.unit_cost * bom.quantity_required * COALESCE(ct.tariff_rate_pct, 0) / 100
          + COALESCE(cr.cost_per_kg * bom.total_part_weight_kg, 0)
          + COALESCE(cr.cost_per_unit * bom.quantity_required, 0), 4) AS landed_cost,
    COALESCE(cr.transit_days, 0) AS transit_days,
    COALESCE(cr.transport_mode, 'Unknown') AS transport_mode,
    pc.supplier_rating, pc.lead_time_days
FROM SLV_PRODUCT_BOM bom
JOIN SLV_PARTS_COSTED pc ON bom.part_id = pc.part_id
JOIN GLD_DIM_PRODUCT dp ON bom.product_id = dp.product_id
JOIN GLD_DIM_PART dpart ON bom.part_id = dpart.part_id
JOIN GLD_DIM_SUPPLIER ds ON pc.supplier_id = ds.supplier_id
JOIN GLD_DIM_COUNTRY dc ON pc.supplier_country_code = dc.country_code
LEFT JOIN current_tariffs ct ON pc.supplier_country_code = ct.source_country_code AND bom.product_category = ct.product_category
LEFT JOIN cheapest_routes cr ON pc.supplier_country_code = cr.origin_country_code
WHERE pc.supplier_part_active = TRUE AND pc.supplier_active = TRUE;

CREATE OR REPLACE TABLE GLD_FACT_TARIFF_IMPACT AS
SELECT ROW_NUMBER() OVER (ORDER BY t.tariff_id) AS tariff_impact_key,
    dc.country_key AS source_country_key, t.hs_code, t.product_category,
    t.tariff_rate_pct, t.tariff_type, t.tariff_band,
    TO_NUMBER(TO_CHAR(t.effective_date, 'YYYYMMDD')) AS effective_date_key,
    t.effective_date, t.end_date, t.is_active
FROM SLV_ACTIVE_TARIFFS t
JOIN GLD_DIM_COUNTRY dc ON t.source_country_code = dc.country_code;


-- ============================================================================
-- SECTION 5: SEMANTIC VIEW
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW SV_TARIFF_INTELLIGENCE
  TABLES (
    procurement AS DJURITZ.TARIFF.GLD_FACT_PROCUREMENT PRIMARY KEY (PROCUREMENT_KEY)
      WITH SYNONYMS ('procurement options', 'sourcing options', 'landed cost analysis')
      COMMENT = 'Procurement options with landed costs including tariffs and shipping',
    tariff_impact AS DJURITZ.TARIFF.GLD_FACT_TARIFF_IMPACT PRIMARY KEY (TARIFF_IMPACT_KEY)
      WITH SYNONYMS ('tariff changes', 'tariff history', 'duty rates')
      COMMENT = 'Tariff rates over time by country and product category',
    dim_product AS DJURITZ.TARIFF.GLD_DIM_PRODUCT PRIMARY KEY (PRODUCT_KEY)
      WITH SYNONYMS ('products', 'items', 'goods') COMMENT = 'Product dimension',
    dim_part AS DJURITZ.TARIFF.GLD_DIM_PART PRIMARY KEY (PART_KEY)
      WITH SYNONYMS ('parts', 'components', 'materials') COMMENT = 'Part dimension',
    dim_supplier AS DJURITZ.TARIFF.GLD_DIM_SUPPLIER PRIMARY KEY (SUPPLIER_KEY)
      WITH SYNONYMS ('suppliers', 'vendors', 'manufacturers') COMMENT = 'Supplier dimension',
    dim_country AS DJURITZ.TARIFF.GLD_DIM_COUNTRY PRIMARY KEY (COUNTRY_KEY)
      WITH SYNONYMS ('countries', 'nations', 'origins') COMMENT = 'Country dimension',
    dim_date AS DJURITZ.TARIFF.GLD_DIM_DATE PRIMARY KEY (DATE_KEY)
      WITH SYNONYMS ('dates', 'calendar') COMMENT = 'Date dimension'
  )
  RELATIONSHIPS (
    procurement_to_product AS procurement (PRODUCT_KEY) REFERENCES dim_product,
    procurement_to_part AS procurement (PART_KEY) REFERENCES dim_part,
    procurement_to_supplier AS procurement (SUPPLIER_KEY) REFERENCES dim_supplier,
    procurement_to_country AS procurement (SUPPLIER_COUNTRY_KEY) REFERENCES dim_country,
    tariff_to_country AS tariff_impact (SOURCE_COUNTRY_KEY) REFERENCES dim_country,
    tariff_to_date AS tariff_impact (EFFECTIVE_DATE_KEY) REFERENCES dim_date
  )
  FACTS (
    procurement.unit_cost_fact AS UNIT_COST COMMENT = 'Base unit cost from supplier',
    procurement.total_part_cost_fact AS TOTAL_PART_COST COMMENT = 'Total cost for parts in quantity',
    procurement.tariff_cost_fact AS TARIFF_COST COMMENT = 'Tariff/duty dollar amount',
    procurement.shipping_cost_fact AS TOTAL_SHIPPING_COST COMMENT = 'Total shipping cost',
    procurement.landed_cost_fact AS LANDED_COST COMMENT = 'Fully loaded cost: part + tariff + shipping',
    procurement.tariff_rate_fact AS TARIFF_RATE_PCT COMMENT = 'Tariff rate percentage',
    procurement.quantity_fact AS QUANTITY_REQUIRED COMMENT = 'Parts quantity required',
    procurement.supplier_rating_fact AS SUPPLIER_RATING COMMENT = 'Supplier quality rating',
    procurement.lead_time_fact AS LEAD_TIME_DAYS COMMENT = 'Supplier lead time in days',
    procurement.transit_days_fact AS TRANSIT_DAYS COMMENT = 'Shipping transit days',
    tariff_impact.tariff_rate_impact_fact AS tariff_impact.TARIFF_RATE_PCT COMMENT = 'Tariff rate for impact analysis'
  )
  DIMENSIONS (
    dim_product.product_name AS PRODUCT_NAME WITH SYNONYMS = ('product', 'item name') COMMENT = 'Product name',
    dim_product.product_category AS PRODUCT_CATEGORY WITH SYNONYMS = ('category', 'product type') COMMENT = 'Product category',
    dim_product.sub_category AS SUB_CATEGORY WITH SYNONYMS = ('subcategory') COMMENT = 'Product subcategory',
    dim_product.msrp_dim AS dim_product.MSRP WITH SYNONYMS = ('retail price', 'list price') COMMENT = 'MSRP',
    dim_part.part_name AS PART_NAME WITH SYNONYMS = ('component name') COMMENT = 'Part name',
    dim_part.part_number AS PART_NUMBER WITH SYNONYMS = ('part no', 'part code') COMMENT = 'Part number',
    dim_part.part_category AS PART_CATEGORY WITH SYNONYMS = ('component type') COMMENT = 'Part category',
    dim_supplier.supplier_name AS SUPPLIER_NAME WITH SYNONYMS = ('vendor name') COMMENT = 'Supplier name',
    dim_supplier.supplier_country AS SUPPLIER_COUNTRY WITH SYNONYMS = ('vendor country', 'source country') COMMENT = 'Supplier country',
    dim_supplier.supplier_region AS SUPPLIER_REGION WITH SYNONYMS = ('vendor region') COMMENT = 'Supplier region',
    dim_supplier.supplier_continent AS dim_supplier.SUPPLIER_CONTINENT COMMENT = 'Supplier continent',
    dim_country.country_name AS COUNTRY_NAME WITH SYNONYMS = ('country', 'nation') COMMENT = 'Country name',
    dim_country.country_code_dim AS dim_country.COUNTRY_CODE WITH SYNONYMS = ('iso code') COMMENT = 'ISO country code',
    dim_country.region AS REGION WITH SYNONYMS = ('geographic region') COMMENT = 'Region',
    dim_country.continent AS CONTINENT COMMENT = 'Continent',
    dim_date.full_date AS FULL_DATE WITH SYNONYMS = ('date') COMMENT = 'Calendar date',
    dim_date.year_num AS YEAR_NUM WITH SYNONYMS = ('year') COMMENT = 'Year',
    dim_date.quarter_label AS QUARTER_LABEL WITH SYNONYMS = ('quarter') COMMENT = 'Quarter',
    dim_date.month_name AS MONTH_NAME WITH SYNONYMS = ('month') COMMENT = 'Month',
    procurement.is_critical_dim AS procurement.IS_CRITICAL WITH SYNONYMS = ('critical part') COMMENT = 'Is critical component',
    procurement.transport_mode_dim AS procurement.TRANSPORT_MODE WITH SYNONYMS = ('shipping method') COMMENT = 'Transport mode',
    procurement.tariff_type_dim AS procurement.TARIFF_TYPE WITH SYNONYMS = ('duty type') COMMENT = 'Tariff type',
    tariff_impact.hs_code_dim AS tariff_impact.HS_CODE WITH SYNONYMS = ('harmonized code', 'commodity code') COMMENT = 'HS code',
    tariff_impact.tariff_band_dim AS tariff_impact.TARIFF_BAND COMMENT = 'Tariff severity band',
    tariff_impact.product_category_dim AS tariff_impact.PRODUCT_CATEGORY WITH SYNONYMS = ('tariff product category') COMMENT = 'Tariff product category'
  )
  METRICS (
    procurement.total_landed_cost AS SUM(procurement.landed_cost_fact) WITH SYNONYMS = ('total cost', 'total spend') COMMENT = 'Sum of landed costs',
    procurement.avg_landed_cost AS AVG(procurement.landed_cost_fact) WITH SYNONYMS = ('average cost') COMMENT = 'Average landed cost',
    procurement.total_tariff_cost AS SUM(procurement.tariff_cost_fact) WITH SYNONYMS = ('total duties') COMMENT = 'Total tariff costs',
    procurement.total_shipping AS SUM(procurement.shipping_cost_fact) WITH SYNONYMS = ('total freight cost') COMMENT = 'Total shipping costs',
    procurement.avg_tariff_rate AS AVG(procurement.tariff_rate_fact) WITH SYNONYMS = ('average tariff') COMMENT = 'Average tariff rate',
    procurement.procurement_count AS COUNT(procurement.PROCUREMENT_KEY) WITH SYNONYMS = ('number of options') COMMENT = 'Count of procurement options',
    procurement.min_landed_cost AS MIN(procurement.landed_cost_fact) WITH SYNONYMS = ('cheapest option') COMMENT = 'Minimum landed cost',
    procurement.max_landed_cost AS MAX(procurement.landed_cost_fact) WITH SYNONYMS = ('most expensive') COMMENT = 'Maximum landed cost',
    procurement.avg_supplier_rating AS AVG(procurement.supplier_rating_fact) WITH SYNONYMS = ('vendor rating') COMMENT = 'Average supplier rating',
    procurement.avg_lead_time AS AVG(procurement.lead_time_fact) COMMENT = 'Average lead time in days',
    procurement.avg_transit_days AS AVG(procurement.transit_days_fact) COMMENT = 'Average transit days',
    tariff_impact.avg_tariff_rate_impact USING (tariff_to_country) AS AVG(tariff_impact.tariff_rate_impact_fact) COMMENT = 'Average tariff rate by country',
    tariff_impact.max_tariff_rate USING (tariff_to_country) AS MAX(tariff_impact.tariff_rate_impact_fact) WITH SYNONYMS = ('highest tariff') COMMENT = 'Max tariff rate',
    tariff_impact.tariff_record_count USING (tariff_to_country) AS COUNT(tariff_impact.TARIFF_IMPACT_KEY) COMMENT = 'Count of tariff records',
    tariff_pct_of_landed AS DIV0(procurement.total_tariff_cost, procurement.total_landed_cost) * 100 WITH SYNONYMS = ('tariff share') COMMENT = 'Tariff % of landed cost',
    shipping_pct_of_landed AS DIV0(procurement.total_shipping, procurement.total_landed_cost) * 100 WITH SYNONYMS = ('shipping share') COMMENT = 'Shipping % of landed cost'
  )
  COMMENT = 'Tariff & procurement intelligence for a US manufacturer sourcing globally. Analyze landed costs, tariff impacts, supplier optimization, and supply chain efficiency.'
  AI_SQL_GENERATION 'Models a US manufacturer buying parts globally. Landed cost = part cost + tariff + shipping. Product categories: Electronics, Appliances, Industrial, Automotive. Round to 2 decimals.'
  AI_QUESTION_CATEGORIZATION 'Redirect unrelated questions. Clarify if user wants current vs historical tariffs.';


-- ============================================================================
-- SECTION 6: GIT INTEGRATION (requires ACCOUNTADMIN for API INTEGRATION)
-- ============================================================================

-- 6.1 API Integration
-- USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE API INTEGRATION GIT_TARIFF_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/diegojuritz-atrium')
  API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION GIT_TARIFF_INTEGRATION TO ROLE DATA_ENGINEERING;

-- 6.2 Git Repository
-- USE ROLE DATA_ENGINEERING;
CREATE OR REPLACE GIT REPOSITORY DJURITZ.TARIFF.DEMO_INTELLIGENCE_TARIFF
  API_INTEGRATION = GIT_TARIFF_INTEGRATION
  ORIGIN = 'https://github.com/diegojuritz-atrium/demo-intelligence-tariff.git';

ALTER GIT REPOSITORY DJURITZ.TARIFF.DEMO_INTELLIGENCE_TARIFF FETCH;


-- ============================================================================
-- SECTION 7: DBT PROJECT
-- ============================================================================
-- The dbt project is deployed via the Snowflake Workspace UI:
--   1. Open Workspace connected to the Git repo
--   2. Click Connect → Deploy dbt project
--   3. Select target: dev, warehouse: DE_WH
--
-- To verify:
-- SHOW DBT PROJECTS IN SCHEMA DJURITZ.TARIFF;
--
-- To run manually:
-- EXECUTE DBT PROJECT DJURITZ.TARIFF.TARIFF_INTELLIGENCE ARGS='build --target dev';


-- ============================================================================
-- SECTION 8: TASKS (Scheduling)
-- ============================================================================

CREATE OR ALTER TASK DJURITZ.TARIFF.DBT_RUN_DAILY
  WAREHOUSE = DE_WH
  SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
AS
  EXECUTE DBT PROJECT DJURITZ.TARIFF.TARIFF_INTELLIGENCE ARGS = 'run --target dev';

CREATE OR ALTER TASK DJURITZ.TARIFF.DBT_TEST_DAILY
  WAREHOUSE = DE_WH
  AFTER DJURITZ.TARIFF.DBT_RUN_DAILY
AS
  EXECUTE DBT PROJECT DJURITZ.TARIFF.TARIFF_INTELLIGENCE ARGS = 'test --target dev';

-- Activate tasks (child first, then parent)
ALTER TASK DJURITZ.TARIFF.DBT_TEST_DAILY RESUME;
ALTER TASK DJURITZ.TARIFF.DBT_RUN_DAILY RESUME;

-- To suspend:
-- ALTER TASK DJURITZ.TARIFF.DBT_RUN_DAILY SUSPEND;
-- ALTER TASK DJURITZ.TARIFF.DBT_TEST_DAILY SUSPEND;


-- ============================================================================
-- SECTION 9: CORTEX AGENT (Snowflake Intelligence)
-- ============================================================================
-- The agent is created via the Snowflake Intelligence UI:
--   1. Navigate to AI & ML → Intelligence
--   2. Create new agent: TARIFF_AGENT in DJURITZ.TARIFF
--   3. Add tool: Cortex Analyst (text-to-SQL)
--      - Name: tariff_intelligence_agent
--      - Semantic View: DJURITZ.TARIFF.SV_TARIFF_INTELLIGENCE
--   4. Save and publish
--
-- Alternatively via SQL:

CREATE OR REPLACE AGENT DJURITZ.TARIFF.TARIFF_AGENT
  COMMENT = 'Tariff Intelligence Agent for procurement optimization'
  PROFILE = '{"display_name": "tariff_agent"}'
  AGENT_SPEC = '{
    "models": {"orchestration": "auto"},
    "orchestration": {},
    "tools": [{
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "tariff_intelligence_agent",
        "description": "Answers questions about procurement costs, tariffs, suppliers, shipping routes, and landed costs for a US-based manufacturer sourcing globally.",
        "semantic_view": "DJURITZ.TARIFF.SV_TARIFF_INTELLIGENCE"
      }
    }]
  }';


-- ============================================================================
-- SECTION 10: GRANTS
-- ============================================================================

GRANT REFERENCES, SELECT ON SEMANTIC VIEW DJURITZ.TARIFF.SV_TARIFF_INTELLIGENCE TO ROLE DEMO_AGENT_RL;
GRANT SELECT ON ALL TABLES IN SCHEMA DJURITZ.TARIFF TO ROLE DJURITZ_READONLY;
GRANT SELECT ON ALL VIEWS IN SCHEMA DJURITZ.TARIFF TO ROLE DJURITZ_READONLY;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Row counts
SELECT 'RAW_COUNTRIES' AS table_name, COUNT(*) AS row_count FROM DJURITZ.TARIFF.RAW_COUNTRIES
UNION ALL SELECT 'RAW_PRODUCT_CATALOG', COUNT(*) FROM DJURITZ.TARIFF.RAW_PRODUCT_CATALOG
UNION ALL SELECT 'RAW_PARTS', COUNT(*) FROM DJURITZ.TARIFF.RAW_PARTS
UNION ALL SELECT 'RAW_PRODUCT_PARTS', COUNT(*) FROM DJURITZ.TARIFF.RAW_PRODUCT_PARTS
UNION ALL SELECT 'RAW_SUPPLIERS', COUNT(*) FROM DJURITZ.TARIFF.RAW_SUPPLIERS
UNION ALL SELECT 'RAW_PARTS_SUPPLIER', COUNT(*) FROM DJURITZ.TARIFF.RAW_PARTS_SUPPLIER
UNION ALL SELECT 'RAW_MARKET_TARIFFS', COUNT(*) FROM DJURITZ.TARIFF.RAW_MARKET_TARIFFS
UNION ALL SELECT 'RAW_ROUTES', COUNT(*) FROM DJURITZ.TARIFF.RAW_ROUTES
UNION ALL SELECT 'SLV_SUPPLIERS', COUNT(*) FROM DJURITZ.TARIFF.SLV_SUPPLIERS
UNION ALL SELECT 'SLV_PARTS_COSTED', COUNT(*) FROM DJURITZ.TARIFF.SLV_PARTS_COSTED
UNION ALL SELECT 'SLV_PRODUCT_BOM', COUNT(*) FROM DJURITZ.TARIFF.SLV_PRODUCT_BOM
UNION ALL SELECT 'SLV_ACTIVE_TARIFFS', COUNT(*) FROM DJURITZ.TARIFF.SLV_ACTIVE_TARIFFS
UNION ALL SELECT 'SLV_SHIPPING_ROUTES', COUNT(*) FROM DJURITZ.TARIFF.SLV_SHIPPING_ROUTES
UNION ALL SELECT 'GLD_DIM_DATE', COUNT(*) FROM DJURITZ.TARIFF.GLD_DIM_DATE
UNION ALL SELECT 'GLD_DIM_COUNTRY', COUNT(*) FROM DJURITZ.TARIFF.GLD_DIM_COUNTRY
UNION ALL SELECT 'GLD_DIM_PRODUCT', COUNT(*) FROM DJURITZ.TARIFF.GLD_DIM_PRODUCT
UNION ALL SELECT 'GLD_DIM_PART', COUNT(*) FROM DJURITZ.TARIFF.GLD_DIM_PART
UNION ALL SELECT 'GLD_DIM_SUPPLIER', COUNT(*) FROM DJURITZ.TARIFF.GLD_DIM_SUPPLIER
UNION ALL SELECT 'GLD_FACT_PROCUREMENT', COUNT(*) FROM DJURITZ.TARIFF.GLD_FACT_PROCUREMENT
UNION ALL SELECT 'GLD_FACT_TARIFF_IMPACT', COUNT(*) FROM DJURITZ.TARIFF.GLD_FACT_TARIFF_IMPACT
ORDER BY 1;

-- Test semantic view
SELECT * FROM SEMANTIC_VIEW(
  DJURITZ.TARIFF.SV_TARIFF_INTELLIGENCE
  METRICS procurement.avg_landed_cost, procurement.avg_tariff_rate, procurement.procurement_count
  DIMENSIONS dim_supplier.supplier_country
)
ORDER BY PROCUREMENT_COUNT DESC
LIMIT 10;

-- Show all objects
SHOW OBJECTS IN SCHEMA DJURITZ.TARIFF;
SHOW SEMANTIC VIEWS IN SCHEMA DJURITZ.TARIFF;
SHOW TASKS IN SCHEMA DJURITZ.TARIFF;
SHOW GIT REPOSITORIES IN SCHEMA DJURITZ.TARIFF;
SHOW DBT PROJECTS IN SCHEMA DJURITZ.TARIFF;
SHOW AGENTS IN SCHEMA DJURITZ.TARIFF;
