select
    {{ dbt_utils.generate_surrogate_key(['country_code']) }} as jurisdiction_key,
    country_code,
    country_name,
    fatf_status,
    fatf_status in ('HIGH_RISK', 'MONITORED')               as is_high_risk
from {{ ref('jurisdictions') }}
