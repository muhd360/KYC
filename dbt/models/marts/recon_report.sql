with src as (
    select
        source_table,
        row_count   as source_rows,
        counted_at
    from {{ source('control', 'source_counts') }}
    qualify row_number() over (partition by source_table order by counted_at desc) = 1
),
tgt as (
    select 'clients'         as source_table, count(*) as target_rows from {{ source('raw', 'clients') }}
    union all
    select 'contact_persons',                 count(*) from {{ source('raw', 'contact_persons') }}
    union all
    select 'kyc_events',                      count(*) from {{ source('raw', 'kyc_events') }}
)
select
    s.source_table,
    s.source_rows,
    t.target_rows,
    s.counted_at,
    iff(s.source_rows = t.target_rows, 'PASS', 'FAIL') as status
from src s
join tgt t using (source_table)
