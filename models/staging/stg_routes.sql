select
    route_id,
    origin_country_code,
    destination_country_code,
    transport_mode,
    transit_days,
    cost_per_kg,
    cost_per_unit,
    reliability_score,
    is_active
from {{ source('tariff_raw', 'RAW_ROUTES') }}
