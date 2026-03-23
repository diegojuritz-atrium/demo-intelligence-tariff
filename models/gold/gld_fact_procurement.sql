{{
    config(
        alias='GLD_FACT_PROCUREMENT'
    )
}}

with current_tariffs as (
    select
        source_country_code,
        product_category,
        tariff_rate_pct,
        tariff_type,
        tariff_band
    from (
        select
            source_country_code,
            product_category,
            tariff_rate_pct,
            tariff_type,
            tariff_band,
            row_number() over (
                partition by source_country_code, product_category
                order by effective_date desc
            ) as rn
        from {{ ref('slv_active_tariffs') }}
        where is_active = true
    )
    where rn = 1
),

cheapest_routes as (
    select
        origin_country_code,
        transport_mode,
        cost_per_kg,
        cost_per_unit,
        transit_days,
        reliability_score,
        speed_tier
    from (
        select
            origin_country_code,
            transport_mode,
            cost_per_kg,
            cost_per_unit,
            transit_days,
            reliability_score,
            speed_tier,
            row_number() over (
                partition by origin_country_code
                order by cost_per_kg asc
            ) as rn
        from {{ ref('slv_shipping_routes') }}
        where is_active = true
    )
    where rn = 1
)

select
    row_number() over (
        order by bom.product_id, bom.part_id, pc.supplier_id
    ) as procurement_key,
    dp.product_key,
    dpart.part_key,
    ds.supplier_key,
    dc.country_key as supplier_country_key,
    bom.quantity_required,
    bom.is_critical,
    pc.unit_cost,
    round(pc.unit_cost * bom.quantity_required, 4) as total_part_cost,
    coalesce(ct.tariff_rate_pct, 0) as tariff_rate_pct,
    coalesce(ct.tariff_type, 'None') as tariff_type,
    round(
        pc.unit_cost * bom.quantity_required
        * coalesce(ct.tariff_rate_pct, 0) / 100, 4
    ) as tariff_cost,
    coalesce(cr.cost_per_kg, 0) as shipping_cost_per_kg,
    coalesce(cr.cost_per_unit, 0) as shipping_cost_per_unit,
    round(
        coalesce(cr.cost_per_kg * bom.total_part_weight_kg, 0)
        + coalesce(cr.cost_per_unit * bom.quantity_required, 0), 4
    ) as total_shipping_cost,
    round(
        pc.unit_cost * bom.quantity_required
        + pc.unit_cost * bom.quantity_required * coalesce(ct.tariff_rate_pct, 0) / 100
        + coalesce(cr.cost_per_kg * bom.total_part_weight_kg, 0)
        + coalesce(cr.cost_per_unit * bom.quantity_required, 0), 4
    ) as landed_cost,
    coalesce(cr.transit_days, 0) as transit_days,
    coalesce(cr.transport_mode, 'Unknown') as transport_mode,
    pc.supplier_rating,
    pc.lead_time_days
from {{ ref('slv_product_bom') }} bom
join {{ ref('slv_parts_costed') }} pc
    on bom.part_id = pc.part_id
join {{ ref('gld_dim_product') }} dp
    on bom.product_id = dp.product_id
join {{ ref('gld_dim_part') }} dpart
    on bom.part_id = dpart.part_id
join {{ ref('gld_dim_supplier') }} ds
    on pc.supplier_id = ds.supplier_id
join {{ ref('gld_dim_country') }} dc
    on pc.supplier_country_code = dc.country_code
left join current_tariffs ct
    on pc.supplier_country_code = ct.source_country_code
    and bom.product_category = ct.product_category
left join cheapest_routes cr
    on pc.supplier_country_code = cr.origin_country_code
where pc.supplier_part_active = true
  and pc.supplier_active = true
