-- Fixed cohort: annual commits already active on 1 Jan 2026 and still active at August.
-- Cumulative consumed share and value-weighted elapsed share, by segment and currency.
with commits as (
    select
        oi.order_item_id,
        a.segment,
        o.currency_iso_code as currency,
        o.effective_date,
        oi.end_date,
        oi.quantity as commit_qty,
        oi.quantity * oi.unit_price / fx.conversion_rate as commit_usd
    from {{ ref('stg_salesforce__order_item') }} oi
    inner join {{ ref('stg_salesforce__order') }} o
        on oi.order_id = o.order_id
    inner join {{ ref('stg_salesforce__product2') }} p
        on oi.product_id = p.product_id
    inner join {{ ref('stg_salesforce__account') }} a
        on o.account_id = a.account_id
    inner join {{ ref('int_fx__daily_rates') }} fx
        on fx.rate_date = o.effective_date
       and fx.currency_code = o.currency_iso_code
    where p.product_code = 'API-COMMIT'
      and o.status = 'Activated'
      and oi.quantity > 0
      and o.effective_date <= date '2026-01-01'
      and oi.end_date >= date '2026-08-31'
      and date_diff('day', o.effective_date, oi.end_date) between 300 and 400
),

months as (
    select month_end
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
      and month_end >= date '2026-01-31'
),

used as (
    select
        m.month_end,
        c.segment,
        c.currency,
        c.order_item_id,
        c.commit_qty,
        c.commit_usd,
        c.effective_date,
        c.end_date,
        coalesce(sum(u.total_usage), 0) as used_qty
    from months m
    inner join commits c
        on c.effective_date <= m.month_end
       and c.end_date >= m.month_end
    left join {{ ref('stg_billing__usage_record_summary') }} u
        on u.metadata_salesforce_order_item_id = c.order_item_id
       and u.period_end >= date '2026-01-01'
       and u.period_end <= m.month_end
    group by 1, 2, 3, 4, 5, 6, 7, 8
),

scored as (
    select
        month_end,
        segment,
        currency,
        commit_usd,
        commit_usd * used_qty / nullif(commit_qty, 0) as consumed_value
    from used
)

select
    strftime(month_end, '%Y-%m-%d') as month_key,
    month_end,
    coalesce(segment, 'All') as segment,
    coalesce(currency, 'All') as currency,
    count(*) as active_commits,
    sum(commit_usd) as commit_usd,
    sum(consumed_value) / nullif(sum(commit_usd), 0) as share_consumed,
    (date_diff('day', date '2026-01-01', month_end) + 1) / 365.0 as straight_line
from scored
group by grouping sets (
    (month_end),
    (month_end, segment),
    (month_end, currency),
    (month_end, segment, currency)
)
