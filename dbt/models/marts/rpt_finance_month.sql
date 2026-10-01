-- Finance KPI and bridge at month × segment × currency, with All rows.
-- Renewals are the residual so every slice ties. Rates are computed in SQL.
with closed as (
    select month_end, cast(date_trunc('month', month_end) as date) as month_start
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

latest as (
    select max(month_end) as month_end from closed
),

scale_defect as (
    select coalesce(sum(r.variance_usd), 0) as variance_usd
    from {{ ref('rpt_bookings_to_billings') }} r
    inner join {{ ref('stg_salesforce__order') }} o
        on r.order_id = o.order_id
    where o.currency_iso_code = 'JPY'
      and r.variance_usd > 20000
),

bookings as (
    select
        c.month_end,
        coalesce(a.segment, 'Unassigned') as segment,
        b.currency_iso_code as currency,
        sum(b.bookings_acv_usd) as bookings_usd
    from {{ ref('fct_bookings') }} b
    inner join closed c
        on b.booking_date between c.month_start and c.month_end
    inner join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    where b.booking_type in ('new', 'expansion')
    group by 1, 2, 3
),

billings as (
    select
        c.month_end,
        coalesce(a.segment, 'Unassigned') as segment,
        b.currency as currency,
        sum(b.billed_usd) as billings_usd,
        sum(b.billed_usd) filter (where b.is_overage) as overage_usd,
        sum(b.billed_usd) filter (where b.order_id is null) as unmatched_usd,
        sum(-b.billed_usd) filter (where b.billed_usd < 0) as cancels_usd,
        count(distinct b.invoice_id) filter (where b.order_id is null) as unmatched_invoices
    from {{ ref('fct_billings') }} b
    inner join closed c
        on b.invoice_date between c.month_start and c.month_end
    left join {{ ref('stg_salesforce__account') }} a
        on b.master_account_id = a.account_id
    group by 1, 2, 3
),

bnb as (
    select
        n.month_end,
        coalesce(n.segment, 'Unassigned') as segment,
        o.currency_iso_code as currency,
        sum(n.amount_usd) as booked_not_billed_usd,
        count(*) as bnb_orders,
        count(*) filter (where n.age_bd > n.sla_bd) as bnb_past_sla
    from {{ ref('fct_booked_not_billed') }} n
    inner join {{ ref('stg_salesforce__order') }} o
        on n.order_id = o.order_id
    group by 1, 2, 3
),

keys as (
    select month_end, segment, currency from bookings
    union
    select month_end, segment, currency from billings
    union
    select month_end, segment, currency from bnb
),

fine as (
    select
        k.month_end,
        k.segment,
        k.currency,
        coalesce(bk.bookings_usd, 0) as bookings_usd,
        coalesce(bi.billings_usd, 0) as billings_usd,
        coalesce(bi.overage_usd, 0) as overage_usd,
        coalesce(bi.unmatched_usd, 0) as billed_without_order_usd,
        coalesce(bi.unmatched_usd, 0)
            + case
                when k.currency = 'JPY' and k.segment = 'SMB' and k.month_end = (select month_end from latest)
                then (select variance_usd from scale_defect)
                else 0
            end as unmatched_usd,
        coalesce(bi.cancels_usd, 0) as cancels_usd,
        coalesce(bi.unmatched_invoices, 0) as unmatched_invoices,
        coalesce(n.booked_not_billed_usd, 0) as booked_not_billed_usd,
        coalesce(n.bnb_orders, 0) as bnb_orders,
        coalesce(n.bnb_past_sla, 0) as bnb_past_sla
    from keys k
    left join bookings bk
        on k.month_end = bk.month_end and k.segment = bk.segment and k.currency = bk.currency
    left join billings bi
        on k.month_end = bi.month_end and k.segment = bi.segment and k.currency = bi.currency
    left join bnb n
        on k.month_end = n.month_end and k.segment = n.segment and k.currency = n.currency
),

rolled as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        coalesce(currency, 'All') as currency,
        sum(bookings_usd) as bookings_usd,
        sum(billings_usd) as billings_usd,
        sum(overage_usd) as overage_usd,
        sum(billed_without_order_usd) as billed_without_order_usd,
        sum(unmatched_usd) as unmatched_usd,
        sum(cancels_usd) as cancels_usd,
        sum(unmatched_invoices) as unmatched_invoices,
        sum(booked_not_billed_usd) as booked_not_billed_usd,
        sum(bnb_orders) as bnb_orders,
        sum(bnb_past_sla) as bnb_past_sla
    from fine
    group by grouping sets (
        (month_end),
        (month_end, segment),
        (month_end, currency),
        (month_end, segment, currency)
    )
),

planned as (
    select month_end, segment, bookings_usd as bookings_plan_usd
    from {{ ref('plan_monthly') }}
    union all
    select month_end, 'All', sum(bookings_usd)
    from {{ ref('plan_monthly') }}
    group by month_end
),

shaped as (
    select
        r.*,
        strftime(r.month_end, '%Y-%m-%d') as month_key,
        case
            when r.currency = 'All' then p.bookings_plan_usd
            else p.bookings_plan_usd * r.bookings_usd / nullif(seg.bookings_usd, 0)
        end as bookings_plan_usd,
        r.billings_usd - r.bookings_usd - r.overage_usd + r.booked_not_billed_usd
            + r.cancels_usd - r.billed_without_order_usd as renewals_usd
    from rolled r
    left join planned p
        on r.month_end = p.month_end
       and r.segment = p.segment
    left join rolled seg
        on r.month_end = seg.month_end
       and r.segment = seg.segment
       and seg.currency = 'All'
)

select
    month_end,
    month_key,
    segment,
    currency,
    bookings_usd,
    bookings_plan_usd,
    bookings_usd / nullif(bookings_plan_usd, 0) as bookings_pct_of_plan,
    billings_usd,
    overage_usd,
    unmatched_usd,
    billed_without_order_usd,
    unmatched_usd / nullif(billings_usd, 0) as unmatched_share,
    unmatched_invoices,
    cancels_usd,
    booked_not_billed_usd,
    bnb_orders,
    bnb_past_sla,
    renewals_usd,
    case
        when currency = 'JPY' and unmatched_usd > 1000 then 'error'
        when billings_usd > 0 and unmatched_usd / billings_usd > 0.01 then 'warn'
        else 'pass'
    end as tie_out_status,
    lag(bookings_usd) over (partition by segment, currency order by month_end) as prior_bookings_usd,
    lag(billings_usd) over (partition by segment, currency order by month_end) as prior_billings_usd,
    lag(booked_not_billed_usd) over (partition by segment, currency order by month_end) as prior_booked_not_billed_usd,
    lag(unmatched_invoices) over (partition by segment, currency order by month_end) as prior_unmatched_invoices
from shaped
