{{
    config(
        alias='GLD_DIM_PRODUCT'
    )
}}

select
    product_id as product_key,
    product_id,
    product_name,
    product_category,
    sub_category,
    msrp,
    weight_kg,
    launch_date,
    is_active
from {{ ref('stg_product_catalog') }}
