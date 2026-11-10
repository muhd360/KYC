-- Returns clients that have more than one row with is_current = TRUE.
select client_id, count(*) as current_rows
from {{ ref('dim_client') }}
where is_current = true
group by client_id
having count(*) > 1
