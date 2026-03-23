{{
    config(
        alias='SLV_PRODUCT_BOM'
    )
}}

select
    pp.product_part_id,
    pp.product_id,
    pc.product_name,
    pc.product_category,
    pc.sub_category,
    pp.part_id,
    p.part_number,
    p.part_name,
    p.part_category,
    p.unit_of_measure,
    p.weight_kg as part_weight_kg,
    pp.quantity_required,
    pp.is_critical,
    round(p.weight_kg * pp.quantity_required, 4) as total_part_weight_kg
from {{ ref('stg_product_parts') }} pp
join {{ ref('stg_product_catalog') }} pc on pp.product_id = pc.product_id
join {{ ref('stg_parts') }} p on pp.part_id = p.part_id
