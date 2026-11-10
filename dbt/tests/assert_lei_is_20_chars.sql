-- Returns rows that break the rule: every LEI must be exactly 20 characters.
select lei
from {{ ref('dim_legal_entity') }}
where length(lei) != 20
