{{ config(severity='error') }}
-- Returns any FAIL rows from today's reconciliation run.
select *
from {{ ref('recon_report') }}
where status = 'FAIL'
