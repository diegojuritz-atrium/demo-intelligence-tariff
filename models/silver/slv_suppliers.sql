{{
    config(
        alias='SLV_SUPPLIERS'
    )
}}

select
    s.supplier_id,
    s.supplier_name,
    s.country_code,
    c.country_name as supplier_country,
    c.region as supplier_region,
    c.continent as supplier_continent,
    s.city as supplier_city,
    s.supplier_rating,
    s.lead_time_days,
    s.is_active
from {{ ref('stg_suppliers') }} s
join {{ ref('stg_countries') }} c
    on s.country_code = c.country_code
