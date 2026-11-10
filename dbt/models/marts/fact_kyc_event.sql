{{ config(materialized='incremental', unique_key='event_id') }}

select
    e.event_id,
    c.client_key,
    le.entity_key,
    j.jurisdiction_key,
    to_number(to_char(e.event_ts, 'YYYYMMDD'))  as date_key,
    e.event_type,
    c.risk_rating                               as risk_rating_at_event,
    e.event_ts,
    e.updated_at                                as source_updated_at
from {{ ref('stg_onboarding__kyc_events') }} e
left join {{ ref('dim_client') }} c
       on c.client_id = e.client_id
      and e.event_ts >= c.valid_from
      and (e.event_ts < c.valid_to or c.valid_to is null)
left join {{ ref('dim_legal_entity') }} le on le.lei = c.lei
left join {{ ref('dim_jurisdiction') }} j  on j.country_code = c.country_code

{% if is_incremental() %}
where e.updated_at > (select max(source_updated_at) from {{ this }})
{% endif %}
