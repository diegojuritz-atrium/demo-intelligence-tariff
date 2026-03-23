select
    tariff_id,
    source_country_code,
    destination_country_code,
    hs_code,
    product_category,
    tariff_rate_pct,
    effective_date,
    end_date,
    tariff_type,
    is_active
from {{ source('tariff_raw', 'RAW_MARKET_TARIFFS') }}
