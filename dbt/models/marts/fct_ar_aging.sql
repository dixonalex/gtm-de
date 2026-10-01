-- Open AR at each closed month-end, aged from the invoice due date.
-- Written-off invoices are uncollectible and are not AR.
-- DSO is month-end AR divided by trailing-three-month billings, times 91.
with closed as (
    select month_end
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

open_ar as (
    select
        c.month_end,
        i.invoice_id,
        i.amount_due / fx.conversion_rate as remaining_usd,
        date_diff('day', cast(i.due_date as date), c.month_end) as days_past_due
    from closed c
    inner join {{ ref('stg_billing__invoice') }} i
        on cast(i.created as date) <= c.month_end
       and (
           i.status_transitions_paid_at is null
           or cast(i.status_transitions_paid_at as date) > c.month_end
       )
       and (
           i.marked_uncollectible_at is null
           or cast(i.marked_uncollectible_at as date) > c.month_end
       )
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = cast(i.created as date)
       and fx.currency_code = i.currency
    where i.status != 'void'
      and i.amount_due > 0
),

bucketed as (
    select
        month_end,
        case
            when days_past_due <= 0 then 'current'
            when days_past_due <= 30 then '1_30'
            when days_past_due <= 90 then '31_90'
            else 'over_90'
        end as bucket,
        remaining_usd
    from open_ar
),

billings as (
    select
        cast(date_trunc('month', invoice_date) + interval 1 month - interval 1 day as date) as month_end,
        sum(billed_usd) as billed_usd
    from {{ ref('fct_billings') }}
    group by 1
),

trailing_billings as (
    select
        c.month_end,
        sum(b.billed_usd) as billed_usd
    from closed c
    left join billings b
        on b.month_end between cast(date_trunc('month', c.month_end) - interval 2 month as date)
            and c.month_end
    group by c.month_end
)

select
    b.month_end,
    sum(b.remaining_usd) filter (where b.bucket = 'current') as current_usd,
    sum(b.remaining_usd) filter (where b.bucket = '1_30') as bucket_1_30_usd,
    sum(b.remaining_usd) filter (where b.bucket = '31_90') as bucket_31_90_usd,
    sum(b.remaining_usd) filter (where b.bucket = 'over_90') as over_90_usd,
    sum(b.remaining_usd) as ar_usd,
    sum(b.remaining_usd) / nullif(g.billed_usd, 0) * 91 as dso_days
from bucketed b
left join trailing_billings g on b.month_end = g.month_end
group by b.month_end, g.billed_usd
