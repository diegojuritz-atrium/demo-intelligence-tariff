select
    part_id,
    part_number,
    part_name,
    part_category,
    unit_of_measure,
    weight_kg
from {{ source('tariff_raw', 'RAW_PARTS') }}
