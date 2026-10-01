with product as (
    select order_id, product_code
    from (
        select
            oi.order_id,
            p.product_code,
            row_number() over (
                partition by oi.order_id
                order by oi.quantity * oi.unit_price desc, p.product_code
            ) as rn
        from staging.stg_salesforce__order_item oi
        inner join staging.stg_salesforce__product2 p
            on oi.product_id = p.product_id
    )
    where rn = 1
)

select
    n.month_end,
    n.order_id,
    n.account_name,
    n.segment,
    n.owner_name,
    n.effective_date,
    n.amount_usd,
    n.age_bd,
    n.sla_bd,
    pr.product_code
from marts.fct_booked_not_billed n
left join product pr on n.order_id = pr.order_id
