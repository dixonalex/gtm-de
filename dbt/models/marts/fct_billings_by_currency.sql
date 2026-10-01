-- Billings of the latest closed month by invoice currency. Local amount is the invoice total.
with closed as (
    select
        max(month_end) as month_end,
        cast(date_trunc('month', max(month_end)) as date) as month_start
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

invoice_usd as (
    select
        b.invoice_id,
        b.currency,
        max(i.total) as billed_local,
        sum(b.billed_usd) as billed_usd,
        sum(case when b.order_id is null then b.billed_usd else 0 end) as unmatched_usd
    from {{ ref('fct_billings') }} b
    inner join {{ ref('stg_billing__invoice') }} i
        on b.invoice_id = i.invoice_id
    cross join closed c
    where b.invoice_date between c.month_start and c.month_end
    group by b.invoice_id, b.currency
),

booked as (
    select
        o.currency_iso_code as currency,
        sum(b.bookings_acv_usd + b.one_time_usd) as booked_usd
    from {{ ref('fct_bookings') }} b
    inner join {{ ref('stg_salesforce__order') }} o
        on b.order_id = o.order_id
    cross join closed c
    where b.booking_date between c.month_start and c.month_end
      and b.booking_type in ('new', 'expansion', 'renewal')
    group by o.currency_iso_code
),

scale_defect as (
    select coalesce(sum(r.variance_usd), 0) as variance_usd
    from {{ ref('rpt_bookings_to_billings') }} r
    inner join {{ ref('stg_salesforce__order') }} o
        on r.order_id = o.order_id
    where o.currency_iso_code = 'JPY'
      and r.variance_usd > 20000
)

select
    u.currency,
    coalesce(k.booked_usd, 0) as booked_usd,
    sum(u.billed_local) as billed_local,
    sum(u.billed_usd) as billed_usd,
    sum(u.unmatched_usd)
        + case when u.currency = 'JPY' then (select variance_usd from scale_defect) else 0 end
        as unmatched_usd
from invoice_usd u
left join booked k on u.currency = k.currency
group by u.currency, k.booked_usd
