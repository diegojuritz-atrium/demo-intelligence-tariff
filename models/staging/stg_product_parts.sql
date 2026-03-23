select
    product_part_id,
    product_id,
    part_id,
    quantity_required,
    is_critical
from {{ source('tariff_raw', 'RAW_PRODUCT_PARTS') }}
