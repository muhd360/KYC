select
    person_id,
    client_id,
    full_name,
    date_of_birth,
    nationality,
    role,
    updated_at
from {{ source('raw', 'contact_persons') }}
qualify row_number() over (partition by person_id order by updated_at desc) = 1
