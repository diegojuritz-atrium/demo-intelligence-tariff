{{
    config(
        alias='SLV_ACTIVE_TARIFFS'
    )
}}

select
    t.tariff_id,
    t.source_country_code,
    sc.country_name as source_country,
    sc.region as source_region,
    sc.continent as source_continent,
    t.destination_country_code,
    t.hs_code,
    t.product_category,
    t.tariff_rate_pct,
    t.effective_date,
    t.end_date,
    t.tariff_type,
    t.is_active,
    case
        when t.tariff_rate_pct = 0 then 'Zero'
        when t.tariff_rate_pct < 5 then 'Low'
        when t.tariff_rate_pct < 15 then 'Medium'
        when t.tariff_rate_pct < 25 then 'High'
        else 'Very High'
    end as tariff_band
from {{ ref('stg_market_tariffs') }} t
join {{ ref('stg_countries') }} sc
    on t.source_country_code = sc.country_code
