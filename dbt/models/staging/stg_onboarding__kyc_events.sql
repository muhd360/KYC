select
    event_id,
    client_id,
    event_type,
    event_ts,
    performed_by,
    updated_at
from {{ source('raw', 'kyc_events') }}
