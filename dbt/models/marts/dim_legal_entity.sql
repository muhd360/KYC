select
    {{ dbt_utils.generate_surrogate_key(['lei']) }} as entity_key,
    lei,
    legal_name,
    country_code,
    legal_form_code,
    entity_status,
    registration_status,
    loaded_at
from {{ ref('stg_gleif__entities') }}
