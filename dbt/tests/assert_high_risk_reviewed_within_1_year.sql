{{ config(severity='warn') }}
-- Returns current HIGH-risk clients whose last_review_date is more than 12 months ago.
select client_id, risk_rating, last_review_date
from {{ ref('dim_client') }}
where is_current     = true
  and risk_rating    = 'HIGH'
  and last_review_date < dateadd('month', -12, current_date())
