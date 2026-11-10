# KYC Client Onboarding Warehouse

**Snowflake · dbt · Airflow · Python · PostgreSQL**

A portfolio project building a daily Airflow pipeline that loads five sources into Snowflake, models a star schema with SCD Type 2 client history, builds corporate ownership chains, and enforces dynamic data masking.

> **Data notice:** GLEIF data is used under the Creative Commons Attribution 4.0 licence. Postgres client data is fully synthetic.

---

## Architecture

*(Add draw.io / Excalidraw PNG here)*

---

## Results

*(Fill from results.md once runs are complete)*

---

## How to run

### Prerequisites

| Tool | Version |
|---|---|
| Python | 3.11 |
| Docker Desktop | latest |
| Astro CLI | latest |
| Snowflake account | Enterprise trial |

### 1. Clone and install

```bash
git clone <repo>
cd kyc-warehouse
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Generate Snowflake key pair

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

Add `rsa_key.p8` to `.gitignore`. Paste the public key contents (without header/footer) into `snowflake/setup.sql`.

### 3. Snowflake setup

Run `snowflake/setup.sql` as ACCOUNTADMIN. Use Snowflake's web UI or SnowSQL.

### 4. Start local services

```bash
docker compose up -d        # starts Postgres on port 5433
astro dev init
astro dev start             # starts Airflow on port 8080
```

### 5. Configure Airflow connections and variables

In the Airflow UI (localhost:8080):

| Connection / Variable | Value |
|---|---|
| Connection: `snowflake_kyc` | user=svc_airflow, key pair auth |
| Connection: `onboarding_db` | host=host.docker.internal, port=5433 |
| Variable: `slack_webhook` | your Slack webhook URL |
| Variable: `snowflake_account` | your `orgname-accountname` |
| Variable: `snowflake_key_path` | path to rsa_key.p8 inside the container |

### 6. Seed the database

```bash
# Run after GLEIF pull (needs gleif_leis.txt)
python postgres/seed.py
```

### 7. Trigger the DAG

Enable `kyc_daily` in the Airflow UI. With `catchup=True` and start_date 30 days back, it will backfill automatically. Set `max_active_runs=1` to keep them sequential.

### 8. dbt locally

```bash
cd dbt
dbt deps
dbt debug
dbt build
```

---

## Screenshots

*(Add: masked vs unmasked query, client rating history, green Airflow grid)*

---

## Limitations

- Client data is simulated; contact persons are Faker-generated
- GLEIF parents represent direct legal ownership, not beneficial ownership
- Watermark loads miss hard deletes (soft-delete flag is loaded)
- SCD2 misses intra-day double changes

## What I'd do next

- CDC via Debezium for Postgres instead of watermark polling
- Beneficial ownership resolution (GLEIF UltimateParent + exceptions)
- ML risk scoring model fed by the star schema
