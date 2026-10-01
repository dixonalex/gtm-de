with orders as (
    select * from {{ ref('stg_salesforce__order') }}
),

order_items as (
    select * from {{ ref('stg_salesforce__order_item') }}
),

accounts as (
    select
        account_id,
        master_account_id
    from {{ ref('int_accounts__deduped') }}
),

periods as (
    select * from (
        values
        ('Annual', 12),
        ('Quarterly', 3),
        ('Monthly', 1)
    ) as v(billing_frequency_c, period_months)
),

slots as (
    select
        o.order_id,
        a.master_account_id,
        o.currency_iso_code,
        p.period_months,
        k.slot_index,
        cast(
            o.effective_date + (k.slot_index * p.period_months) * interval 1 month
            as date
        ) as slot_start
    from orders o
    inner join periods p on o.billing_frequency_c = p.billing_frequency_c
    inner join accounts a on o.account_id = a.account_id
    cross join (select unnest(range(0, 25)) as slot_index) k
    where not o.is_reduction_order
      and cast(
            o.effective_date + (k.slot_index * p.period_months) * interval 1 month
            as date
          ) <= least(o.end_date, current_date)
),

reductions as (
    select
        oi.original_order_item_id,
        ro.effective_date,
        sum(oi.quantity) as qty_delta
    from order_items oi
    inner join orders ro on oi.order_id = ro.order_id
    where ro.is_reduction_order
      and oi.original_order_item_id is not null
    group by oi.original_order_item_id, ro.effective_date
),

item_slots as (
    select
        s.order_id,
        s.master_account_id,
        s.currency_iso_code,
        s.period_months,
        s.slot_index,
        s.slot_start,
        oi.end_date,
        oi.quantity,
        oi.unit_price,
        coalesce(
            sum(r.qty_delta) filter (where r.effective_date <= s.slot_start),
            0
        ) as qty_delta
    from slots s
    inner join order_items oi on s.order_id = oi.order_id
    left join reductions r on r.original_order_item_id = oi.order_item_id
    group by
        s.order_id,
        s.master_account_id,
        s.currency_iso_code,
        s.period_months,
        s.slot_index,
        s.slot_start,
        oi.order_item_id,
        oi.end_date,
        oi.quantity,
        oi.unit_price
)

select
    order_id,
    master_account_id,
    currency_iso_code,
    slot_index,
    slot_start,
    cast(slot_start + period_months * interval 1 month - interval 1 day as date) as slot_end,
    round(sum(
        case
            when end_date is not null then (quantity + qty_delta) * unit_price * period_months / 12.0
            when slot_index = 0 then quantity * unit_price
            else 0
        end
    ), 4) as expected_amount
from item_slots
group by
    order_id,
    master_account_id,
    currency_iso_code,
    period_months,
    slot_index,
    slot_start
