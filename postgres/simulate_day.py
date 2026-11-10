"""
Simulate one day of changes in the onboarding database.
Called by the Airflow DAG with --date YYYY-MM-DD.
Usage: python postgres/simulate_day.py --date 2026-10-15
"""
import argparse
import os
import random
import uuid
from datetime import datetime

import psycopg2
from faker import Faker

fake = Faker()

DSN  = os.getenv("ONBOARDING_DSN", "host=localhost port=5433 dbname=onboarding user=kyc password=kyc")
RATINGS  = ["LOW", "MEDIUM", "HIGH"]
STATUSES = ["SUBMITTED", "IN_REVIEW", "APPROVED", "REJECTED"]

parser = argparse.ArgumentParser()
parser.add_argument("--date", required=True)
args   = parser.parse_args()
run_dt = datetime.fromisoformat(args.date)

conn = psycopg2.connect(DSN)
cur  = conn.cursor()

# Fetch existing client IDs
cur.execute("SELECT client_id FROM clients WHERE is_deleted = FALSE")
all_ids = [r[0] for r in cur.fetchall()]
if not all_ids:
    print("No clients found. Run seed.py first.")
    raise SystemExit(1)

# 2–5 new clients
for _ in range(random.randint(2, 5)):
    new_id = f"C{uuid.uuid4().hex[:6].upper()}"
    cur.execute("""
        INSERT INTO clients
            (client_id, legal_name, country_code, client_type,
             risk_rating, kyc_status, onboarded_at, updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT DO NOTHING
    """, (new_id, fake.company(), fake.country_code(), "CORPORATE",
          "LOW", "SUBMITTED", run_dt.date(), run_dt))
    cur.execute("""
        INSERT INTO kyc_events (event_id, client_id, event_type, event_ts, performed_by, updated_at)
        VALUES (%s,%s,'SUBMITTED',%s,%s,%s)
    """, (str(uuid.uuid4()), new_id, run_dt, fake.user_name(), run_dt))

# A few risk rating changes
for cid in random.sample(all_ids, min(3, len(all_ids))):
    new_rating = random.choice(RATINGS)
    cur.execute("UPDATE clients SET risk_rating=%s, updated_at=%s WHERE client_id=%s",
                (new_rating, run_dt, cid))
    cur.execute("""
        INSERT INTO kyc_events (event_id, client_id, event_type, event_ts, performed_by, updated_at)
        VALUES (%s,%s,'RISK_CHANGE',%s,%s,%s)
    """, (str(uuid.uuid4()), cid, run_dt, fake.user_name(), run_dt))

# A few status changes
for cid in random.sample(all_ids, min(4, len(all_ids))):
    new_status = random.choice(STATUSES)
    cur.execute("UPDATE clients SET kyc_status=%s, updated_at=%s WHERE client_id=%s",
                (new_status, run_dt, cid))
    cur.execute("""
        INSERT INTO kyc_events (event_id, client_id, event_type, event_ts, performed_by, updated_at)
        VALUES (%s,%s,%s,%s,%s,%s)
    """, (str(uuid.uuid4()), cid, new_status, run_dt, fake.user_name(), run_dt))

# Soft-delete one client
victim = random.choice(all_ids)
cur.execute("UPDATE clients SET is_deleted=TRUE, updated_at=%s WHERE client_id=%s",
            (run_dt, victim))

conn.commit()
cur.close()
conn.close()
print(f"Simulated day {args.date}: new clients, rating changes, status changes, 1 soft delete.")
