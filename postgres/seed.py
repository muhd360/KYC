"""
Seed the onboarding database with 250 synthetic clients.
Run the GLEIF pull first so real LEIs are available in gleif_leis.txt.
Usage: python postgres/seed.py
"""
import csv
import os
import random
import uuid
from datetime import date, timedelta

import psycopg2
from faker import Faker

fake = Faker()
Faker.seed(0)
random.seed(0)

DSN = os.getenv("ONBOARDING_DSN", "host=localhost port=5433 dbname=onboarding user=kyc password=kyc")

# Load real LEIs written by the GLEIF extract script
with open("gleif_leis.txt") as f:
    lei_pool = [line.strip() for line in f if line.strip()]

TYPES    = ["CORPORATE", "FUND", "BANK"]
RATINGS  = ["LOW", "MEDIUM", "HIGH"]
STATUSES = ["SUBMITTED", "IN_REVIEW", "APPROVED", "REJECTED"]
ROLES    = ["DIRECTOR", "AUTHORISED_SIGNATORY"]
EVENTS   = ["SUBMITTED", "APPROVED", "REJECTED", "PERIODIC_REVIEW", "RISK_CHANGE"]

conn = psycopg2.connect(DSN)
cur  = conn.cursor()

for i in range(250):
    client_id   = f"C{i:04d}"
    lei         = random.choice(lei_pool) if lei_pool else None
    onboarded   = date(2023, 1, 1) + timedelta(days=random.randint(0, 365))
    last_review = onboarded + timedelta(days=random.randint(30, 500))

    cur.execute("""
        INSERT INTO clients
            (client_id, legal_name, lei, country_code, client_type,
             risk_rating, kyc_status, onboarded_at, last_review_date, updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT DO NOTHING
    """, (client_id, fake.company(), lei, fake.country_code(),
          random.choice(TYPES), random.choice(RATINGS),
          random.choice(STATUSES), onboarded, last_review, onboarded))

    for _ in range(random.randint(1, 3)):
        cur.execute("""
            INSERT INTO contact_persons
                (person_id, client_id, full_name, date_of_birth, nationality, role)
            VALUES (%s,%s,%s,%s,%s,%s)
            ON CONFLICT DO NOTHING
        """, (str(uuid.uuid4()), client_id, fake.name(),
              fake.date_of_birth(minimum_age=25, maximum_age=70),
              fake.country_code(), random.choice(ROLES)))

    for event_type in ["SUBMITTED", random.choice(EVENTS)]:
        cur.execute("""
            INSERT INTO kyc_events (event_id, client_id, event_type, event_ts, performed_by)
            VALUES (%s,%s,%s,%s,%s)
            ON CONFLICT DO NOTHING
        """, (str(uuid.uuid4()), client_id, event_type,
              fake.date_time_between(start_date=onboarded), fake.user_name()))

conn.commit()
cur.close()
conn.close()
print("Seeded 250 clients.")
