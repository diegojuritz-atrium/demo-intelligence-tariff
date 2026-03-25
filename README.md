# Tariff Intelligence Demo

> Snowflake Intelligence demo for a US-based manufacturer optimizing global procurement costs under tariff scenarios.

**Repository:** [github.com/diegojuritz-atrium/demo-intelligence-tariff](https://github.com/diegojuritz-atrium/demo-intelligence-tariff)
**Platform:** Snowflake · dbt · Snowflake Intelligence
**Database:** `DEMO_INTELLIGENCE` · **Schema:** `TARIFF`

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Data Model](#-data-model)
- [dbt Project](#-dbt-project)
- [Semantic View](#-semantic-view)
- [Snowflake Intelligence Agent](#-snowflake-intelligence-agent)
- [Demo Questions](#-demo-questions)
- [Infrastructure Setup](#-infrastructure-setup)
- [How to Replicate](#-how-to-replicate)

---

## 🎯 Overview

A US-based manufacturing company sources parts from **500+ suppliers across 25 countries** to assemble products in 4 categories: Electronics, Appliances, Industrial, and Automotive. Government tariffs, shipping costs, and supplier pricing all impact the **total landed cost** of each procurement decision.

This demo showcases how **Snowflake Intelligence** helps operations, finance, and supply chain teams answer critical business questions in natural language — without writing SQL.

### Business Problem

```
Landed Cost = Part Cost + Tariff Cost + Shipping Cost
```

The company needs to:
- Monitor daily tariff changes across 49 trading partner countries
- Identify the cheapest sourcing options considering all cost components
- Evaluate alternative suppliers when tariffs shift
- Reduce supply chain risk by diversifying sourcing

---

## 🏗️ Architecture

### Medallion Architecture (Bronze → Silver → Gold)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   RAW_*          stg_*           SLV_*           GLD_*      │
│  (Bronze)      (Staging)       (Silver)         (Gold)      │
│                                                             │
│  ┌───────┐    ┌─────────┐    ┌───────────┐    ┌──────────┐ │
│  │Source │───▶│  Views   │───▶│ Enriched  │───▶│   Star   │ │
│  │Tables │    │(cleanup) │    │ (joined)  │    │  Schema  │ │
│  └───────┘    └─────────┘    └───────────┘    └──────────┘ │
│                                                     │       │
│                                                     ▼       │
│                                            ┌──────────────┐ │
│                                            │  Semantic     │ │
│                                            │  View         │ │
│                                            └──────┬───────┘ │
│                                                   ▼         │
│                                            ┌──────────────┐ │
│                                            │  Snowflake   │ │
│                                            │  Intelligence│ │
│                                            └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Prefix | Materialization | Purpose |
|-------|--------|-----------------|---------|
| Bronze | `RAW_` | Tables (source data) | Synthetic raw data, simulates ERP/external feeds |
| Staging | `stg_` | Views | Thin wrappers, column cleanup, trimming |
| Silver | `SLV_` | Tables | Enriched joins, business logic, classifications |
| Gold | `GLD_` | Tables | Star schema — dimensions and facts for analytics |

---

## 📊 Data Model

### Bronze Layer — Source Tables (~50,000 records)

| Table | Rows | Description |
|-------|------|-------------|
| `RAW_COUNTRIES` | 50 | Reference table: 50 trading partner countries with region/continent |
| `RAW_PRODUCT_CATALOG` | 200 | Products across 4 categories and 25 subcategories |
| `RAW_PARTS` | 1,000 | Components across 20 categories (Semiconductors, Displays, etc.) |
| `RAW_PRODUCT_PARTS` | 5,000 | Bill of Materials — which parts go into which products |
| `RAW_SUPPLIERS` | 500 | Suppliers across 25 countries with ratings and lead times |
| `RAW_PARTS_SUPPLIER` | 10,000 | Part-supplier mappings with unit costs and preferred flags |
| `RAW_MARKET_TARIFFS` | 30,000 | Government tariffs by country, HS code, and date (6 tariff types) |
| `RAW_ROUTES` | 3,250 | Shipping routes: 7 transport modes × 10 variants × 49 countries |

### Silver Layer — Enriched Transformations

| Table | Description |
|-------|-------------|
| `SLV_SUPPLIERS` | Suppliers joined with country names, regions, and continents |
| `SLV_PARTS_COSTED` | Parts with supplier costs, ratings, and country details |
| `SLV_PRODUCT_BOM` | Bill of materials with part weights and product categories |
| `SLV_ACTIVE_TARIFFS` | Tariffs enriched with country names and severity bands (Zero → Very High) |
| `SLV_SHIPPING_ROUTES` | Routes enriched with country details and speed tiers (Express → Slow) |

### Gold Layer — Star Schema

**Dimensions:**

| Table | Key | Description |
|-------|-----|-------------|
| `GLD_DIM_DATE` | `DATE_KEY` | Calendar dimension (2019–2026) with quarters, weeks, weekends |
| `GLD_DIM_COUNTRY` | `COUNTRY_KEY` | Country hierarchy: code → name → region → continent |
| `GLD_DIM_PRODUCT` | `PRODUCT_KEY` | Product hierarchy: name → subcategory → category |
| `GLD_DIM_PART` | `PART_KEY` | Part details: number, name, category, weight |
| `GLD_DIM_SUPPLIER` | `SUPPLIER_KEY` | Supplier details: name, country, rating, lead time |

**Facts:**

| Table | Rows | Description |
|-------|------|-------------|
| `GLD_FACT_PROCUREMENT` | 42,968 | Every product → part → supplier combination with landed cost breakdown |
| `GLD_FACT_TARIFF_IMPACT` | 30,000 | Tariff rate history by country, HS code, and product category |

---

## ⚙️ dbt Project

### Project Structure

```
tariff_intelligence/
├── dbt_project.yml
├── profiles.yml              # Not committed (in .gitignore)
├── macros/
│   └── generate_schema_name.sql
├── models/
│   ├── staging/              # 8 views + 2 YAML configs
│   │   ├── _stg_sources.yml
│   │   ├── _stg_schema.yml
│   │   └── stg_*.sql
│   ├── silver/               # 5 tables + 1 YAML config
│   │   ├── _slv_schema.yml
│   │   └── slv_*.sql
│   └── gold/                 # 7 tables + 1 YAML config
│       ├── _gld_schema.yml
│       └── gld_*.sql
```

### Key Stats

- **20 models** (8 views + 12 tables)
- **59 tests** (unique, not_null, accepted_values)
- **8 sources** (RAW_* tables)

### Running dbt

```bash
# Full build (models + tests)
dbt build --project-dir /workspace/tariff_intelligence

# Compile only (no execution)
dbt compile --project-dir /workspace/tariff_intelligence

# Run tests only
dbt test --project-dir /workspace/tariff_intelligence
```

### Scheduling with Snowflake Tasks

The dbt project is deployed as a **Snowflake DBT PROJECT** object and can be scheduled:

```sql
-- Create a scheduled task (adjust time as needed)
CREATE OR ALTER TASK DEMO_INTELLIGENCE.TARIFF.TASK_DBT_BUILD
  WAREHOUSE = DE_WH
  SCHEDULE = 'USING CRON 0 6 * * * America/New_York'  -- Daily at 6 AM ET
AS
  EXECUTE DBT PROJECT DEMO_INTELLIGENCE.TARIFF.TARIFF_INTELLIGENCE
    ARGS='build --target dev';

-- Activate the task
ALTER TASK DEMO_INTELLIGENCE.TARIFF.TASK_DBT_BUILD RESUME;

-- Suspend when not needed
ALTER TASK DEMO_INTELLIGENCE.TARIFF.TASK_DBT_BUILD SUSPEND;

-- Check task status
SHOW TASKS IN SCHEMA DEMO_INTELLIGENCE.TARIFF;
```

---

## 🔍 Semantic View

The semantic view `SV_TARIFF_INTELLIGENCE` sits on top of the gold star schema and provides a business-friendly interface for Snowflake Intelligence.

### What It Contains

- **7 tables** connected via relationships (fact-to-dimension joins)
- **11 facts:** unit cost, tariff cost, shipping cost, landed cost, quantity, supplier rating, lead time, transit days
- **25 dimensions:** product, part, supplier, country, date hierarchies, tariff type, transport mode
- **16 metrics:** total/avg landed cost, tariff %, shipping %, procurement count, min/max costs
- **Synonyms:** business-friendly aliases (e.g., "total spend" → `total_landed_cost`, "vendor" → supplier)
- **AI instructions:** guides the LLM on how to interpret business questions

### Example Query

```sql
SELECT * FROM SEMANTIC_VIEW(
  DEMO_INTELLIGENCE.TARIFF.SV_TARIFF_INTELLIGENCE
  METRICS procurement.avg_landed_cost, procurement.avg_tariff_rate
  DIMENSIONS dim_supplier.supplier_country
)
ORDER BY AVG_LANDED_COST DESC;
```

---

## 🤖 Snowflake Intelligence Agent

The `TARIFF_AGENT` in `DEMO_INTELLIGENCE.TARIFF` uses the semantic view as its tool, allowing users to ask business questions in natural language and receive SQL-backed answers.

### Target Personas

| Persona | Focus Area |
|---------|------------|
| VP Supply Chain | Supplier diversification, route optimization, risk |
| CFO / Finance | Tariff cost exposure, working capital, cost reduction |
| Operations Manager | Daily sourcing decisions, lead times, shipping |
| Procurement Lead | Supplier comparison, alternative sourcing, pricing |

---

## 💬 Demo Questions

These questions are designed to showcase business value during client and channel demos. Each targets a specific persona and pain point.

### Cost Optimization and Tariff Impact

**1. "Which supplier countries have the lowest landed cost for our Electronics product line, and how much would we save by shifting 20% of our sourcing there?"**
- 👤 **Persona:** CFO / Procurement Lead
- 💡 **Value:** Identifies immediate cost savings by reallocating spend to lower-tariff countries
- 🔎 **Shows:** Multi-dimensional cost analysis across countries

**2. "If tariffs on Chinese imports increase to 45%, which alternative suppliers in Vietnam or India can provide the same parts at a lower total landed cost?"**
- 👤 **Persona:** VP Supply Chain
- 💡 **Value:** Proactive scenario planning for tariff changes — the core use case
- 🔎 **Shows:** What-if analysis, supplier substitution, landed cost comparison

**3. "What percentage of our total procurement spend is going to tariffs versus shipping? Where is the biggest opportunity to reduce costs?"**
- 👤 **Persona:** CFO
- 💡 **Value:** Identifies whether tariff negotiation or route optimization has higher ROI
- 🔎 **Shows:** Cost breakdown analysis, spend allocation

### Supply Chain and Route Decisions

**4. "For our top 10 highest-cost products, what is the cheapest shipping route for each, and how many transit days would we add by switching from air freight to ocean?"**
- 👤 **Persona:** Operations Manager
- 💡 **Value:** Trade-off analysis between cost and speed for logistics decisions
- 🔎 **Shows:** Route optimization, transit time impact

**5. "Which critical parts have only one active supplier? What's our risk exposure if tariffs change for those countries?"**
- 👤 **Persona:** VP Supply Chain
- 💡 **Value:** Supply chain risk assessment — single points of failure
- 🔎 **Shows:** Supplier concentration risk, dependency analysis

**6. "Show me all parts where we're currently paying a 'Very High' tariff rate — are there alternative suppliers in countries with lower tariff bands that maintain a supplier rating above 3.5?"**
- 👤 **Persona:** Procurement Lead
- 💡 **Value:** Actionable supplier switch recommendations with quality constraints
- 🔎 **Shows:** Multi-criteria filtering (tariff band + supplier rating)

### Strategic Planning and What-If Analysis

**7. "Compare the total tariff cost impact by continent — are we overexposed to any single region, and what does a diversified sourcing strategy look like?"**
- 👤 **Persona:** CFO / VP Supply Chain
- 💡 **Value:** Portfolio-level risk assessment and diversification strategy
- 🔎 **Shows:** Geographic concentration analysis

**8. "Which product categories have the highest tariff cost as a percentage of landed cost? Where should our finance team focus renegotiation efforts?"**
- 👤 **Persona:** CFO
- 💡 **Value:** Prioritizes finance team efforts on highest-impact categories
- 🔎 **Shows:** Relative tariff burden by category

### Daily Operations and Working Capital

**9. "What are our top 5 most expensive procurement options right now, and what's the cheapest alternative for each that keeps lead time under 30 days?"**
- 👤 **Persona:** Operations Manager
- 💡 **Value:** Immediate actionable savings with delivery constraints
- 🔎 **Shows:** Constrained optimization (cost vs. lead time)

**10. "Show me the average landed cost trend by supplier country for Automotive parts — which countries are becoming more cost-competitive over time?"**
- 👤 **Persona:** VP Supply Chain / Procurement Lead
- 💡 **Value:** Trend analysis for strategic sourcing shifts
- 🔎 **Shows:** Time-series analysis, competitive landscape

---

## 🔧 Infrastructure Setup

### Git Integration

```sql
-- 1. Create API integration for GitHub
CREATE OR REPLACE API INTEGRATION git_tariff_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/diegojuritz-atrium')
  API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
  ENABLED = TRUE;

-- 2. Grant to working role
GRANT USAGE ON INTEGRATION git_tariff_integration TO ROLE DATA_ENGINEERING;

-- 3. Create Git repository object
CREATE OR REPLACE GIT REPOSITORY DEMO_INTELLIGENCE.TARIFF.DEMO_INTELLIGENCE_TARIFF
  API_INTEGRATION = git_tariff_integration
  ORIGIN = 'https://github.com/diegojuritz-atrium/demo-intelligence-tariff.git';

-- 4. Sync with remote
ALTER GIT REPOSITORY DEMO_INTELLIGENCE.TARIFF.DEMO_INTELLIGENCE_TARIFF FETCH;
```

### dbt Project Deployment

```sql
-- Deploy dbt project from Workspace (via UI: Connect → Deploy dbt project)
-- Or verify deployed project:
SHOW DBT PROJECTS IN SCHEMA DEMO_INTELLIGENCE.TARIFF;
```

### Task Scheduling

```sql
-- Schedule daily dbt build
CREATE OR ALTER TASK DEMO_INTELLIGENCE.TARIFF.TASK_DBT_BUILD
  WAREHOUSE = DE_WH
  SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
AS
  EXECUTE DBT PROJECT DEMO_INTELLIGENCE.TARIFF.TARIFF_INTELLIGENCE
    ARGS='build --target dev';

ALTER TASK DEMO_INTELLIGENCE.TARIFF.TASK_DBT_BUILD RESUME;

-- Suspend when done
ALTER TASK DEMO_INTELLIGENCE.TARIFF.TASK_DBT_BUILD SUSPEND;
```

### Semantic View

```sql
-- Verify semantic view exists
SHOW SEMANTIC VIEWS IN SCHEMA DEMO_INTELLIGENCE.TARIFF;

-- Grant access
GRANT REFERENCES, SELECT ON SEMANTIC VIEW DEMO_INTELLIGENCE.TARIFF.SV_TARIFF_INTELLIGENCE
  TO ROLE DEMO_AGENT_RL;
```

---

## 🚀 How to Replicate

1. **Create schema:** `CREATE SCHEMA DEMO_INTELLIGENCE.TARIFF;`
2. **Run raw data DDL:** Execute `tarrif_complete_setup.sql` to create and populate all `RAW_*` tables, the semantic view, and the Cortex Agent
3. **Deploy the dbt project from Git** — see [Deploying from Git](#-deploying-from-git) below
4. **Run the dbt project:** `dbt build` from the Workspace or schedule via Snowflake Tasks
5. **Test with demo questions** listed above

---

## 📦 Deploying from Git

Since this project is stored in a Git repository, you must manually deploy it into Snowflake. Follow these steps:

### 1. Create the Git Integration

```sql
-- Create API integration for GitHub (requires ACCOUNTADMIN or appropriate privileges)
CREATE OR REPLACE API INTEGRATION git_tariff_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/diegojuritz-atrium')
  API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
  ENABLED = TRUE;

-- Grant to your working role
GRANT USAGE ON INTEGRATION git_tariff_integration TO ROLE DATA_ENGINEERING;
```

### 2. Create the Git Repository Object

```sql
CREATE OR REPLACE GIT REPOSITORY DEMO_INTELLIGENCE.TARIFF.DEMO_INTELLIGENCE_TARIFF
  API_INTEGRATION = git_tariff_integration
  ORIGIN = 'https://github.com/diegojuritz-atrium/demo-intelligence-tariff.git';

-- Fetch latest changes
ALTER GIT REPOSITORY DEMO_INTELLIGENCE.TARIFF.DEMO_INTELLIGENCE_TARIFF FETCH;
```

### 3. Connect a Workspace

1. Open **Snowsight → Workspaces**
2. Create or open a workspace
3. Click **Connect to Git** (top-left, near the branch name)
4. Select the repository `DEMO_INTELLIGENCE.TARIFF.DEMO_INTELLIGENCE_TARIFF`
5. Choose the branch (e.g., `main`)

### 4. Deploy the dbt Project

From the Workspace:
1. Click **Connect → Deploy dbt project** in the workspace toolbar
2. This creates a Snowflake `DBT PROJECT` object that can be executed and scheduled

Or via SQL:
```sql
-- Verify the deployed project
SHOW DBT PROJECTS IN SCHEMA DEMO_INTELLIGENCE.TARIFF;

-- Execute the project
EXECUTE DBT PROJECT DEMO_INTELLIGENCE.TARIFF.TARIFF_INTELLIGENCE
  ARGS = 'build --target dev';
```

### 5. Run the Setup SQL

Execute `tarrif_complete_setup.sql` in a Snowsight worksheet or the Workspace. This creates:
- All `RAW_*` source tables with synthetic data
- The semantic view `SV_TARIFF_INTELLIGENCE`
- The Cortex Agent `TARIFF_AGENT`

### 6. Push Changes Back to Git

From the Workspace:
1. Click the **branch name** (top-left)
2. Stage your changes and commit
3. Click **Push** to sync with GitHub

> **Note:** If push fails with an integration error, disconnect and reconnect the workspace to the Git repository (see [Infrastructure Setup](#-infrastructure-setup)).

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Data Platform | Snowflake |
| Transformation | dbt Core 1.9.4 (in Snowflake) |
| Data Model | Medallion Architecture (Bronze / Silver / Gold) |
| Analytics Layer | Semantic View |
| AI Layer | Snowflake Intelligence (Cortex Agent) |
| Version Control | GitHub + Snowflake Git Integration |
| Scheduling | Snowflake Tasks |
| Development | Snowflake Workspaces + Cortex Code |

---

*Built with Cortex Code · Powered by Snowflake Intelligence*
