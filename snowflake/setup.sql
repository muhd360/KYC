-- Run as ACCOUNTADMIN, then switch roles as shown.

USE ROLE SYSADMIN;
CREATE WAREHOUSE kyc_wh
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE kyc;
CREATE SCHEMA kyc.raw;        -- data exactly as loaded
CREATE SCHEMA kyc.staging;    -- dbt staging and intermediate models
CREATE SCHEMA kyc.snapshots;  -- dbt snapshots (SCD2 history)
CREATE SCHEMA kyc.marts;      -- star schema analysts query
CREATE SCHEMA kyc.control;    -- watermarks, extract logs, reconciliation

CREATE STAGE kyc.raw.files_stage;
CREATE FILE FORMAT kyc.raw.ndjson TYPE = JSON;

-- Raw tables
CREATE TABLE kyc.raw.gleif_entities (
    payload     VARIANT,
    file_name   STRING,
    loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE TABLE kyc.raw.gleif_relationships (
    payload     VARIANT,
    file_name   STRING,
    loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE TABLE kyc.raw.clients            (LIKE kyc.raw.gleif_entities);  -- replaced by Airflow loads
CREATE TABLE kyc.raw.contact_persons    (LIKE kyc.raw.gleif_entities);
CREATE TABLE kyc.raw.kyc_events         (LIKE kyc.raw.gleif_entities);
CREATE TABLE kyc.raw.client_documents (
    doc_id      STRING,
    client_id   STRING,
    doc_type    STRING,
    issued_on   DATE,
    expires_on  DATE,
    verified    BOOLEAN,
    loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE TABLE kyc.raw.screening_results (
    client_id    STRING,
    screened_at  TIMESTAMP_NTZ,
    list_version STRING,
    hit_count    INT,
    loaded_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Control tables
CREATE TABLE kyc.control.watermarks (
    source_table   STRING,
    last_watermark TIMESTAMP_TZ
);
CREATE TABLE kyc.control.extract_log (
    run_id        STRING,
    source_table  STRING,
    rows_extracted INT,
    extracted_at  TIMESTAMP_TZ
);
CREATE TABLE kyc.control.source_counts (
    source_table STRING,
    row_count    INT,
    counted_at   TIMESTAMP_TZ
);

INSERT INTO kyc.control.watermarks VALUES
    ('clients',         '1900-01-01'),
    ('contact_persons', '1900-01-01'),
    ('kyc_events',      '1900-01-01');

-- ----------------------------------------------------------------
-- Roles
-- ----------------------------------------------------------------
USE ROLE SECURITYADMIN;
CREATE ROLE loader;       -- Airflow loads raw data
CREATE ROLE transformer;  -- dbt builds models
CREATE ROLE kyc_analyst;  -- sees personal data
CREATE ROLE reporter;     -- sees masked data only

-- loader: writes raw and control only
GRANT USAGE ON WAREHOUSE kyc_wh TO ROLE loader;
GRANT USAGE ON DATABASE kyc TO ROLE loader;
GRANT USAGE, CREATE TABLE ON SCHEMA kyc.raw TO ROLE loader;
GRANT USAGE ON SCHEMA kyc.control TO ROLE loader;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA kyc.control TO ROLE loader;
GRANT READ, WRITE ON STAGE kyc.raw.files_stage TO ROLE loader;

-- transformer: reads raw, builds everything downstream
GRANT USAGE ON WAREHOUSE kyc_wh TO ROLE transformer;
GRANT USAGE ON DATABASE kyc TO ROLE transformer;
GRANT USAGE ON SCHEMA kyc.raw TO ROLE transformer;
GRANT SELECT ON FUTURE TABLES IN SCHEMA kyc.raw TO ROLE transformer;
GRANT SELECT ON ALL TABLES IN SCHEMA kyc.raw TO ROLE transformer;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA kyc.staging   TO ROLE transformer;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA kyc.snapshots TO ROLE transformer;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA kyc.marts     TO ROLE transformer;

-- analysts and reporters: marts only
GRANT USAGE ON WAREHOUSE kyc_wh TO ROLE kyc_analyst;
GRANT USAGE ON WAREHOUSE kyc_wh TO ROLE reporter;
GRANT USAGE ON DATABASE kyc TO ROLE kyc_analyst;
GRANT USAGE ON DATABASE kyc TO ROLE reporter;
GRANT USAGE ON SCHEMA kyc.marts TO ROLE kyc_analyst;
GRANT USAGE ON SCHEMA kyc.marts TO ROLE reporter;
GRANT SELECT ON FUTURE TABLES IN SCHEMA kyc.marts TO ROLE kyc_analyst;
GRANT SELECT ON FUTURE TABLES IN SCHEMA kyc.marts TO ROLE reporter;
GRANT SELECT ON ALL TABLES IN SCHEMA kyc.marts TO ROLE kyc_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA kyc.marts TO ROLE reporter;

-- Service users (replace public key contents)
CREATE USER svc_airflow TYPE = SERVICE DEFAULT_ROLE = loader
    RSA_PUBLIC_KEY = '<contents of rsa_key.pub without header/footer lines>';
CREATE USER svc_dbt TYPE = SERVICE DEFAULT_ROLE = transformer
    RSA_PUBLIC_KEY = '<contents of rsa_key.pub without header/footer lines>';
GRANT ROLE loader      TO USER svc_airflow;
GRANT ROLE transformer TO USER svc_dbt;

-- ----------------------------------------------------------------
-- Dynamic masking policies (requires Enterprise edition)
-- ----------------------------------------------------------------
USE ROLE SYSADMIN;
CREATE MASKING POLICY kyc.control.mask_name AS (val STRING) RETURNS STRING ->
    CASE WHEN IS_ROLE_IN_SESSION('KYC_ANALYST') THEN val ELSE '*****' END;

CREATE MASKING POLICY kyc.control.mask_dob AS (val DATE) RETURNS DATE ->
    CASE WHEN IS_ROLE_IN_SESSION('KYC_ANALYST') THEN val
         ELSE DATE_FROM_PARTS(YEAR(val), 1, 1) END;
