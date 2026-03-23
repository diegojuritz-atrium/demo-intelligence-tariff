select
    country_code,
    country_name,
    region,
    continent
from {{ source('tariff_raw', 'RAW_COUNTRIES') }}
