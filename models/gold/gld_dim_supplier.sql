{{
    config(
        alias='GLD_DIM_SUPPLIER'
    )
}}

select
    s.supplier_id as supplier_key,
    s.supplier_id,
    s.supplier_name,
    s.country_code as supplier_country_code,
    c.country_name as supplier_country,
    c.region as supplier_region,
    c.continent as supplier_continent,
    s.supplier_city,
    s.supplier_rating,
    s.lead_time_days,
    s.is_active
from {{ ref('slv_suppliers') }} s
join {{ ref('gld_dim_country') }} c
    on s.country_code = c.country_code
