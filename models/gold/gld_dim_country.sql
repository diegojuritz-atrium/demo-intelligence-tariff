{{
    config(
        alias='GLD_DIM_COUNTRY'
    )
}}

select
    row_number() over (order by country_code) as country_key,
    country_code,
    country_name,
    region,
    continent
from {{ ref('stg_countries') }}
