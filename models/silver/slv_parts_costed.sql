{{
    config(
        alias='SLV_PARTS_COSTED'
    )
}}

select
    ps.parts_supplier_id,
    ps.part_id,
    p.part_number,
    p.part_name,
    p.part_category,
    p.weight_kg as part_weight_kg,
    ps.supplier_id,
    s.supplier_name,
    s.country_code as supplier_country_code,
    c.country_name as supplier_country,
    c.region as supplier_region,
    s.supplier_rating,
    s.lead_time_days,
    ps.unit_cost,
    ps.currency,
    ps.min_order_qty,
    ps.is_preferred,
    ps.is_active as supplier_part_active,
    s.is_active as supplier_active
from {{ ref('stg_parts_supplier') }} ps
join {{ ref('stg_parts') }} p on ps.part_id = p.part_id
join {{ ref('stg_suppliers') }} s on ps.supplier_id = s.supplier_id
join {{ ref('stg_countries') }} c on s.country_code = c.country_code
