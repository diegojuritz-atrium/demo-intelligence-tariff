{{
    config(
        alias='GLD_DIM_PART'
    )
}}

select
    part_id as part_key,
    part_id,
    part_number,
    part_name,
    part_category,
    unit_of_measure,
    weight_kg
from {{ ref('stg_parts') }}
