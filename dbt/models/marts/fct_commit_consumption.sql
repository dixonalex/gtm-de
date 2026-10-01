-- Cumulative share of usage-commit quantity consumed, against a straight line through the term.
with commits as (
    select
        oi.order_item_id,
        o.effective_date,
        oi.end_date,
        oi.quantity as commit_qty,
        oi.quantity * oi.unit_price / fx.conversion_rate as commit_usd
    from {{ ref('stg_salesforce__order_item') }} oi
    inner join {{ ref('stg_salesforce__order') }} o
        on oi.order_id = o.order_id
    inner join {{ ref('stg_salesforce__product2') }} p
        on oi.product_id = p.product_id
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
    group by
        m.month_end, c.order_item_id, c.commit_qty, c.commit_usd, c.effective_date, c.end_date
)

select
    month_end,
    count(*) as active_commits,
    sum(commit_usd) as commit_usd,
    sum(commit_usd * used_qty / nullif(commit_qty, 0))
        / nullif(sum(commit_usd), 0) as share_consumed,
    -- Annual commits already active on 1 Jan. Elapsed is the day of the year
    -- over a 365-day term (31 Aug = 243/365), the same line on every commit.
    (date_diff('day', date '2026-01-01', month_end) + 1) / 365.0 as straight_line
from used
group by month_end
