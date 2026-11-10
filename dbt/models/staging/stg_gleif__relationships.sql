-- Adjust JSON paths after inspecting a real record from the GLEIF relationships endpoint.
select
    payload:relationships:lei:data:id::string         as child_lei,
    payload:relationships:directParent:data:id::string as parent_lei,
    payload:relationships:directParent:data:type::string as relationship_type,
    loaded_at
from {{ source('raw', 'gleif_relationships') }}
where payload:relationships:directParent:data:id::string is not null
qualify row_number() over (partition by child_lei order by loaded_at desc) = 1
