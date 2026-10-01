-- AR buckets and DSO at month × segment × currency. vs March is the difference from that month.
with closed as (
    select month_end
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

open_ar as (
    select
        c.month_end,
        coalesce(a.segment, 'Unassigned') as segment,
        i.currency,
        i.amount_due / fx.conversion_rate as remaining_usd,
        date_diff('day', cast(i.due_date as date), c.month_end) as days_past_due
    from closed c
    inner join {{ ref('stg_billing__invoice') }} i
        on cast(i.created as date) <= c.month_end
       and (i.status_transitions_paid_at is null or cast(i.status_transitions_paid_at as date) > c.month_end)
       and (i.marked_uncollectible_at is null or cast(i.marked_uncollectible_at as date) > c.month_end)
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = cast(i.created as date)
       and fx.currency_code = i.currency
    left join {{ ref('stg_billing__customer') }} cust
        on i.customer_id = cust.customer_id
    left join {{ ref('stg_salesforce__account') }} a
        on cust.metadata_salesforce_account_id = a.account_id
    where i.status != 'void'
      and i.amount_due > 0
),

bucketed as (
    select
        month_end,
        segment,
        currency,
        case
            when days_past_due <= 0 then 'current'
            when days_past_due <= 30 then 'd1_30'
            when days_past_due <= 90 then 'd31_90'
            else 'over_90'
        end as bucket,
        remaining_usd
    from open_ar
),

wide as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        coalesce(currency, 'All') as currency,
        sum(remaining_usd) filter (where bucket = 'current') as current_usd,
        sum(remaining_usd) filter (where bucket = 'd1_30') as bucket_1_30_usd,
        sum(remaining_usd) filter (where bucket = 'd31_90') as bucket_31_90_usd,
        sum(remaining_usd) filter (where bucket = 'over_90') as over_90_usd,
        sum(remaining_usd) as ar_usd
    from bucketed
    group by grouping sets (
        (month_end),
        (month_end, segment),
        (month_end, currency),
        (month_end, segment, currency)
    )
),

billed as (
    select
        c.month_end,
        coalesce(a.segment, 'Unassigned') as segment,
        b.currency,
        sum(b.billed_usd) as billed_usd
    from {{ ref('fct_billings') }} b
    inner join closed c
        on b.invoice_date <= c.month_end
       and b.invoice_date > c.month_end - interval 3 month
    left join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    group by 1, 2, 3
),

bill_trail as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        coalesce(currency, 'All') as currency,
        sum(billed_usd) as billed_usd
    from billed
    where true
    group by grouping sets (
        (month_end),
        (month_end, segment),
        (month_end, currency),
        (month_end, segment, currency)
    )
),

aged as (
    select
        w.month_end,
        strftime(w.month_end, '%Y-%m-%d') as month_key,
        w.segment,
        w.currency,
        w.current_usd,
        w.bucket_1_30_usd,
        w.bucket_31_90_usd,
        w.over_90_usd,
        w.ar_usd,
        w.ar_usd / nullif(t.billed_usd, 0) * 91 as dso_days,
        w.over_90_usd / nullif(w.ar_usd, 0) as over_90_share
    from wide w
    left join bill_trail t
        on w.month_end = t.month_end
       and w.segment = t.segment
       and w.currency = t.currency
)

select
    a.*,
    a.current_usd - m.current_usd as current_vs_mar_usd,
    a.bucket_1_30_usd - m.bucket_1_30_usd as bucket_1_30_vs_mar_usd,
    a.bucket_31_90_usd - m.bucket_31_90_usd as bucket_31_90_vs_mar_usd,
    a.over_90_usd - m.over_90_usd as over_90_vs_mar_usd,
    a.ar_usd - m.ar_usd as ar_vs_mar_usd,
    a.dso_days - m.dso_days as dso_vs_mar,
    a.over_90_share > 0.02 as alert_over_90,
    a.dso_days > 45 as alert_dso
from aged a
left join aged m
    on m.month_end = date '2026-03-31'
   and a.segment = m.segment
   and a.currency = m.currency
