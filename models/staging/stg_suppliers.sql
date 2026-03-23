select
    supplier_id,
    trim(supplier_name) as supplier_name,
    country_code,
    trim(city) as city,
    supplier_rating,
    lead_time_days,
    is_active
from {{ source('tariff_raw', 'RAW_SUPPLIERS') }}
