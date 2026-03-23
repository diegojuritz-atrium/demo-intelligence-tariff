select
    parts_supplier_id,
    part_id,
    supplier_id,
    unit_cost,
    currency,
    min_order_qty,
    is_preferred,
    is_active
from {{ source('tariff_raw', 'RAW_PARTS_SUPPLIER') }}
