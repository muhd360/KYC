-- Check JSON paths against one real record first:
-- SELECT payload FROM kyc.raw.gleif_entities LIMIT 1;
select
    payload:attributes:lei::string                         as lei,
    payload:attributes:entity:legalName:name::string       as legal_name,
    payload:attributes:entity:legalAddress:country::string as country_code,
    payload:attributes:entity:legalForm:id::string         as legal_form_code,
    payload:attributes:entity:status::string               as entity_status,
    payload:attributes:registration:status::string         as registration_status,
    loaded_at
from {{ source('raw', 'gleif_entities') }}
qualify row_number() over (partition by lei order by loaded_at desc) = 1
