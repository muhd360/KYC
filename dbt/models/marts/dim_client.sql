select
    dbt_scd_id                              as client_key,
    client_id,
    legal_name,
    lei,
    country_code,
    client_type,
    risk_rating,
    kyc_status,
    last_review_date,
    is_deleted,
    dbt_valid_from                          as valid_from,
    dbt_valid_to                            as valid_to,
    dbt_valid_to is null                    as is_current,
    updated_at
from {{ ref('snap_clients') }}
