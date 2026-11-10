{{
    config(post_hook=[
        "alter table {{ this }} modify column full_name set masking policy kyc.control.mask_name",
        "alter table {{ this }} modify column date_of_birth set masking policy kyc.control.mask_dob",
    ])
}}

select
    person_id,
    client_id,
    full_name,
    date_of_birth,
    nationality,
    role
from {{ ref('stg_onboarding__contact_persons') }}
