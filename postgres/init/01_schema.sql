CREATE TABLE clients (
    client_id        TEXT PRIMARY KEY,
    legal_name       TEXT NOT NULL,
    lei              CHAR(20),
    country_code     CHAR(2),
    client_type      TEXT,              -- CORPORATE, FUND, BANK
    risk_rating      TEXT,              -- LOW, MEDIUM, HIGH
    kyc_status       TEXT,              -- SUBMITTED, IN_REVIEW, APPROVED, REJECTED
    onboarded_at     DATE,
    last_review_date DATE,
    is_deleted       BOOLEAN DEFAULT FALSE,
    updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE contact_persons (
    person_id     TEXT PRIMARY KEY,
    client_id     TEXT REFERENCES clients,
    full_name     TEXT,
    date_of_birth DATE,
    nationality   CHAR(2),
    role          TEXT,                 -- DIRECTOR, AUTHORISED_SIGNATORY
    updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE kyc_events (
    event_id     TEXT PRIMARY KEY,
    client_id    TEXT REFERENCES clients,
    event_type   TEXT,                  -- SUBMITTED, APPROVED, REJECTED, PERIODIC_REVIEW, RISK_CHANGE
    event_ts     TIMESTAMPTZ,
    performed_by TEXT,
    updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    -- respect a timestamp the caller set (simulator sets business dates); otherwise stamp now()
    IF TG_OP = 'UPDATE' AND NEW.updated_at IS DISTINCT FROM OLD.updated_at THEN RETURN NEW; END IF;
    IF TG_OP = 'INSERT' AND NEW.updated_at IS NOT NULL THEN RETURN NEW; END IF;
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_clients BEFORE INSERT OR UPDATE ON clients
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_persons BEFORE INSERT OR UPDATE ON contact_persons
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_events  BEFORE INSERT OR UPDATE ON kyc_events
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
