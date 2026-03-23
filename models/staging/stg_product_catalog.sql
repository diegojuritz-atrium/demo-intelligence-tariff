select
    product_id,
    product_name,
    product_category,
    sub_category,
    msrp,
    weight_kg,
    launch_date,
    is_active
from {{ source('tariff_raw', 'RAW_PRODUCT_CATALOG') }}
