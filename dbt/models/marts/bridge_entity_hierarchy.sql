select
    c.child_lei,
    c.ancestor_lei,
    c.level,
    c.is_ultimate_parent,
    j.is_high_risk as ancestor_in_high_risk_jurisdiction,
    le.country_code as ancestor_country_code
from {{ ref('int_ownership_chain') }} c
left join {{ ref('dim_legal_entity') }} le on le.lei = c.ancestor_lei
left join {{ ref('dim_jurisdiction') }}  j  on j.country_code = le.country_code
