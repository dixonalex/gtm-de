with orders as (
    select * from {{ ref('stg_salesforce__order') }}
),

order_items as (
    select * from {{ ref('stg_salesforce__order_item') }}
),

products as (
    select product_id, product_code
    from {{ ref('stg_salesforce__product2') }}
),

opportunities as (
    select opportunity_id, close_date
    from {{ ref('stg_salesforce__opportunity') }}
),

accounts as (
    select account_id, master_account_id
    from {{ ref('int_accounts__deduped') }}
),

hierarchy as (
    select account_id, ultimate_parent_account_id
    from {{ ref('int_accounts__hierarchy') }}
),

fx as (
    select rate_date, currency_code, conversion_rate
    from {{ ref('int_fx__daily_rates') }}
),

month_ends as (
    select cast(
        date_trunc('month', gs) + interval 1 month - interval 1 day
        as date
    ) as month_end
    from generate_series(
        date_trunc('month', (select min(effective_date) from orders)),
        date_trunc('month', {{ as_of_date() }}),
        interval 1 month
    ) t(gs)
    where cast(date_trunc('month', gs) + interval 1 month - interval 1 day as date) <= {{ as_of_date() }}
),

-- USD is locked at booking date so a renewal does not revalue, and a same-stock renewal is not churn + new.
recurring_items as (
    select
        a.master_account_id,
        o.effective_date,
        oi.end_date,
        o.cancelled_date as cancel_date,
        p.product_code,
        case
            when o.opportunity_id is not null then opp.close_date
            else o.effective_date
        end as booking_date,
        o.currency_iso_code,
        oi.quantity * oi.unit_price as acv_local
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    inner join products p on oi.product_id = p.product_id
    inner join accounts a on o.account_id = a.account_id
    left join opportunities opp on o.opportunity_id = opp.opportunity_id
    where oi.end_date is not null
      and (
          p.product_code like 'SEAT-%'
          or p.product_code in ('SUP-PREM', 'API-COMMIT')
      )
),

priced as (
    select
        i.master_account_id,
        i.effective_date,
        i.end_date,
        i.cancel_date,
        i.product_code,
        i.acv_local / fx.conversion_rate as acv_usd
    from recurring_items i
    inner join fx
        on fx.rate_date = i.booking_date
       and fx.currency_code = i.currency_iso_code
),

active as (
    select
        me.month_end,
        p.master_account_id,
        p.product_code,
        p.acv_usd
    from month_ends me
    inner join priced p
        on p.effective_date <= me.month_end
       and p.end_date >= me.month_end
       and (p.cancel_date is null or p.cancel_date > me.month_end)
),

stock as (
    select
        master_account_id,
        month_end,
        sum(acv_usd) filter (where product_code like 'SEAT-%') as seats_arr_usd,
        sum(acv_usd) filter (where product_code = 'SUP-PREM') as support_arr_usd,
        sum(acv_usd) filter (where product_code = 'API-COMMIT') as commit_arr_usd,
        sum(acv_usd) as committed_arr_usd
    from active
    group by master_account_id, month_end
),

first_month as (
    select
        master_account_id,
        min(month_end) as first_month
    from stock
    group by master_account_id
),

spine as (
    select
        f.master_account_id,
        h.ultimate_parent_account_id,
        me.month_end
    from first_month f
    inner join hierarchy h on f.master_account_id = h.account_id
    inner join month_ends me on me.month_end >= f.first_month
),

overage as (
    select
        master_account_id,
        invoice_date,
        billed_usd
    from {{ ref('fct_billings') }}
    where is_overage
      and master_account_id is not null
),

overage_rate as (
    select
        s.master_account_id,
        s.month_end,
        coalesce(sum(o.billed_usd), 0) * 4 as usage_overage_run_rate_usd
    from spine s
    left join overage o
        on o.master_account_id = s.master_account_id
       and o.invoice_date >= cast(date_trunc('month', s.month_end) - interval 2 month as date)
       and o.invoice_date <= s.month_end
    group by s.master_account_id, s.month_end
),

position as (
    select
        s.master_account_id,
        s.ultimate_parent_account_id,
        s.month_end,
        coalesce(k.seats_arr_usd, 0) as seats_arr_usd,
        coalesce(k.support_arr_usd, 0) as support_arr_usd,
        coalesce(k.commit_arr_usd, 0) as commit_arr_usd,
        coalesce(k.committed_arr_usd, 0) as committed_arr_usd,
        r.usage_overage_run_rate_usd,
        coalesce(
            lag(coalesce(k.committed_arr_usd, 0)) over (
                partition by s.master_account_id
                order by s.month_end
            ),
            0
        ) as opening_arr_usd,
        max(coalesce(k.committed_arr_usd, 0)) over (
            partition by s.master_account_id
            order by s.month_end
            rows between unbounded preceding and 1 preceding
        ) as prior_peak_arr_usd
    from spine s
    left join stock k
        on s.master_account_id = k.master_account_id
       and s.month_end = k.month_end
    left join overage_rate r
        on s.master_account_id = r.master_account_id
       and s.month_end = r.month_end
)

select
    master_account_id,
    ultimate_parent_account_id,
    month_end,
    seats_arr_usd,
    support_arr_usd,
    commit_arr_usd,
    committed_arr_usd,
    usage_overage_run_rate_usd,
    opening_arr_usd,
    case
        when opening_arr_usd = 0
         and committed_arr_usd > 0
         and coalesce(prior_peak_arr_usd, 0) = 0
            then committed_arr_usd
        else 0
    end as arr_new_usd,
    case
        when opening_arr_usd > 0 and committed_arr_usd > opening_arr_usd
            then committed_arr_usd - opening_arr_usd
        else 0
    end as arr_expansion_usd,
    case
        when opening_arr_usd > 0
         and committed_arr_usd != 0
         and committed_arr_usd < opening_arr_usd
            then committed_arr_usd - opening_arr_usd
        else 0
    end as arr_contraction_usd,
    case
        when opening_arr_usd > 0 and committed_arr_usd = 0
            then -opening_arr_usd
        else 0
    end as arr_churn_usd,
    case
        when opening_arr_usd = 0
         and committed_arr_usd > 0
         and coalesce(prior_peak_arr_usd, 0) > 0
            then committed_arr_usd
        else 0
    end as arr_reactivation_usd
from position
