select
    client_id,
    legal_name,
    lei,
    country_code,
    client_type,
    risk_rating,
    kyc_status,
    onboarded_at,
    last_review_date,
    is_deleted,
    updated_at
from {{ source('raw', 'clients') }}
qualify row_number() over (partition by client_id order by updated_at desc) = 1
