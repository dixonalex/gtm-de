-- Activated orders with no invoice whose period starts on or before the closed month-end.
with closed as (
    select month_end
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

invoiced as (
    select distinct
        m.order_id,
        c.month_end
    from {{ ref('int_invoices__to_order') }} m
    inner join {{ ref('stg_billing__invoice') }} i
        on m.invoice_id = i.invoice_id
    inner join closed c
        on i.period_start <= c.month_end
    where m.order_id is not null
      and i.status != 'void'
      and m.match_method != 'unmatched'
),

orders as (
    select
        o.order_id,
        o.account_id,
        a.name as account_name,
        a.segment,
        u.name as owner_name,
        o.effective_date,
        o.currency_iso_code,
        o.total_amount / fx.conversion_rate as amount_usd,
        c.month_end
    from {{ ref('stg_salesforce__order') }} o
    inner join closed c
        on o.effective_date <= c.month_end
       and o.effective_date > c.month_end - interval 1 month
    inner join {{ ref('stg_salesforce__account') }} a
        on o.account_id = a.account_id
    left join {{ ref('stg_salesforce__user') }} u
        on a.owner_id = u.user_id
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = o.effective_date
       and fx.currency_code = o.currency_iso_code
    where o.status = 'Activated'
      and not o.is_reduction_order
)

select
    o.month_end,
    o.order_id,
    o.account_name,
    o.segment,
    o.owner_name,
    o.effective_date,
    o.amount_usd,
    {{ business_days('o.effective_date', 'o.month_end') }} as age_bd,
    cast(p.threshold_value as integer) as sla_bd
from orders o
left join invoiced i
    on o.order_id = i.order_id
   and o.month_end = i.month_end
inner join {{ ref('policy_thresholds') }} p
    on p.threshold_key = 'sla_invoicing_bd'
where i.order_id is null
  and o.amount_usd >= 25000
