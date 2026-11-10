{% snapshot snap_clients %}
{{
    config(
        target_schema = 'snapshots',
        unique_key    = 'client_id',
        strategy      = 'timestamp',
        updated_at    = 'updated_at',
    )
}}

select
    client_id,
    legal_name,
    lei,
    country_code,
    client_type,
    risk_rating,
    kyc_status,
    last_review_date,
    is_deleted,
    updated_at
from {{ ref('stg_onboarding__clients') }}

{% endsnapshot %}
