{{
    config(
        alias='GLD_DIM_DATE'
    )
}}

with date_spine as (
    select dateadd('day', seq4(), '2019-01-01'::date) as date_value
    from table(generator(rowcount => 2800))
)

select
    to_number(to_char(date_value, 'YYYYMMDD')) as date_key,
    date_value as full_date,
    year(date_value) as year_num,
    quarter(date_value) as quarter_num,
    month(date_value) as month_num,
    monthname(date_value) as month_name,
    dayofweek(date_value) as day_of_week,
    dayname(date_value) as day_name,
    dayofyear(date_value) as day_of_year,
    weekofyear(date_value) as week_of_year,
    iff(dayofweek(date_value) in (0, 6), true, false) as is_weekend,
    'Q' || quarter(date_value) || ' ' || year(date_value) as quarter_label,
    monthname(date_value) || ' ' || year(date_value) as month_label
from date_spine
