{{
    config(
        alias='GLD_FACT_TARIFF_IMPACT'
    )
}}

select
    row_number() over (order by t.tariff_id) as tariff_impact_key,
    dc.country_key as source_country_key,
    t.hs_code,
    t.product_category,
    t.tariff_rate_pct,
    t.tariff_type,
    t.tariff_band,
    to_number(to_char(t.effective_date, 'YYYYMMDD')) as effective_date_key,
    t.effective_date,
    t.end_date,
    t.is_active
from {{ ref('slv_active_tariffs') }} t
join {{ ref('gld_dim_country') }} dc
    on t.source_country_code = dc.country_code
