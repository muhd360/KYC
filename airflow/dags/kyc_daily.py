from datetime import datetime, timedelta

import requests
from airflow.decorators import dag, task
from airflow.models import Variable
from airflow.operators.bash import BashOperator

DBT      = "/usr/local/airflow/dbt_venv/bin/dbt"
DBT_ARGS = "--project-dir /usr/local/airflow/dbt --profiles-dir /usr/local/airflow/dbt"


def notify_failure(context):
    ti = context["task_instance"]
    webhook = Variable.get("slack_webhook", default_var=None)
    if webhook:
        requests.post(webhook, json={
            "text": f"KYC pipeline failed: {ti.dag_id}.{ti.task_id} on {context['ds']}"
        })


@dag(
    schedule="45 5 * * *",
    start_date=datetime(2026, 10, 1),
    catchup=True,
    max_active_runs=1,
    default_args={
        "retries":          3,
        "retry_delay":      timedelta(minutes=5),
        "on_failure_callback": notify_failure,
    },
)
def kyc_daily():

    @task
    def simulate_day(data_interval_end=None):
        import subprocess, sys
        date_str = data_interval_end.strftime("%Y-%m-%d")
        subprocess.check_call(
            [sys.executable, "/usr/local/airflow/postgres/simulate_day.py", "--date", date_str]
        )

    @task
    def extract_gleif():
        """Page through GLEIF API, write NDJSON files, PUT to Snowflake stage."""
        import json, time, os
        import requests as req
        from snowflake.connector import connect

        sf = connect(
            account=Variable.get("snowflake_account"),
            user="svc_airflow",
            private_key_file=Variable.get("snowflake_key_path"),
            role="loader",
            warehouse="kyc_wh",
            database="kyc",
            schema="raw",
        )
        # TODO: implement paging through /api/v1/lei-records per country
        # Save each page as NDJSON and PUT to @kyc.raw.files_stage/gleif/entities/
        # Then COPY INTO kyc.raw.gleif_entities
        sf.close()

    @task
    def load_postgres(table: str, data_interval_end=None):
        """Watermark-based incremental extract from Postgres → Snowflake raw."""
        import psycopg2
        import pandas as pd
        from snowflake.connector import connect
        from snowflake.connector.pandas_tools import write_pandas

        watermark_upper = data_interval_end.isoformat()
        pg_dsn = Variable.get("onboarding_dsn")
        pg  = psycopg2.connect(pg_dsn)

        sf = connect(
            account=Variable.get("snowflake_account"),
            user="svc_airflow",
            private_key_file=Variable.get("snowflake_key_path"),
            role="loader", warehouse="kyc_wh", database="kyc", schema="raw",
        )
        cur_sf = sf.cursor()

        cur_sf.execute(f"SELECT last_watermark FROM kyc.control.watermarks WHERE source_table = '{table}'")
        wm = cur_sf.fetchone()[0]

        df = pd.read_sql(
            f"SELECT * FROM {table} WHERE updated_at > %s AND updated_at <= %s",
            pg, params=(wm, watermark_upper)
        )
        if not df.empty:
            write_pandas(sf, df, table.upper(), schema="RAW", database="KYC", auto_create_table=True)
            cur_sf.execute(
                "INSERT INTO kyc.control.extract_log VALUES (%s, %s, %s, current_timestamp())",
                (f"{table}_{watermark_upper}", table, len(df))
            )
            cur_sf.execute(
                "UPDATE kyc.control.watermarks SET last_watermark = %s WHERE source_table = %s",
                (watermark_upper, table)
            )
            cur_sf.execute(
                "INSERT INTO kyc.control.source_counts SELECT %s, COUNT(*), current_timestamp() FROM " + table,
                (table,)
            )
        sf.commit()
        pg.close()
        sf.close()

    @task
    def load_files(data_interval_end=None):
        """Write Parquet document metadata and JSON screening results, PUT to stage, COPY INTO."""
        import pandas as pd
        import json
        from snowflake.connector import connect

        date_str = data_interval_end.strftime("%Y-%m-%d")
        sf = connect(
            account=Variable.get("snowflake_account"),
            user="svc_airflow",
            private_key_file=Variable.get("snowflake_key_path"),
            role="loader", warehouse="kyc_wh", database="kyc", schema="raw",
        )
        # TODO: generate synthetic Parquet + JSON files and PUT/COPY INTO Snowflake
        sf.close()

    freshness = BashOperator(
        task_id="dbt_source_freshness",
        bash_command=f"{DBT} source freshness {DBT_ARGS}",
    )
    build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT} build {DBT_ARGS}",
    )

    sim   = simulate_day()
    loads = [
        extract_gleif(),
        load_files(),
        *[load_postgres.override(task_id=f"load_{t}")(t)
          for t in ["clients", "contact_persons", "kyc_events"]],
    ]
    sim >> loads
    loads >> freshness >> build


kyc_daily()
