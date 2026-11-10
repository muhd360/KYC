with recursive chain as (
    select
        child_lei,
        parent_lei as ancestor_lei,
        1          as level
    from {{ ref('stg_gleif__relationships') }}

    union all

    select
        c.child_lei,
        r.parent_lei,
        c.level + 1
    from chain c
    join {{ ref('stg_gleif__relationships') }} r
        on c.ancestor_lei = r.child_lei
    where c.level < 10  -- guard against cycles in bad data
)
select
    child_lei,
    ancestor_lei,
    level,
    level = max(level) over (partition by child_lei) as is_ultimate_parent
from chain
