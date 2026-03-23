{{
    config(
        alias='SLV_SHIPPING_ROUTES'
    )
}}

select
    r.route_id,
    r.origin_country_code,
    oc.country_name as origin_country,
    oc.region as origin_region,
    oc.continent as origin_continent,
    r.destination_country_code,
    r.transport_mode,
    r.transit_days,
    r.cost_per_kg,
    r.cost_per_unit,
    r.reliability_score,
    r.is_active,
    case
        when r.transit_days <= 3 then 'Express'
        when r.transit_days <= 10 then 'Standard'
        when r.transit_days <= 20 then 'Economy'
        else 'Slow'
    end as speed_tier
from {{ ref('stg_routes') }} r
join {{ ref('stg_countries') }} oc
    on r.origin_country_code = oc.country_code
