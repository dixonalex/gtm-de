-- Currency tie-out, with a local-currency billed amount and a Total row last.
with closed as (
    select month_end, cast(date_trunc('month', month_end) as date) as month_start
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

local_fine as (
    select
        c.month_end,
        coalesce(a.segment, 'Unassigned') as segment,
        i.currency,
        sum(i.total) as billed_local
    from {{ ref('stg_billing__invoice') }} i
    inner join closed c
        on cast(i.created as date) between c.month_start and c.month_end
    left join {{ ref('stg_billing__customer') }} cust
        on i.customer_id = cust.customer_id
    left join {{ ref('stg_salesforce__account') }} a
        on cust.metadata_salesforce_account_id = a.account_id
    where i.status != 'void'
    group by 1, 2, 3
),

local_rolled as (
    select
        month_end,
        coalesce(segment, 'All') as segment,
        currency,
        sum(billed_local) as billed_local
    from local_fine
    group by grouping sets (
        (month_end, currency),
        (month_end, segment, currency)
    )
)

select
    f.month_key,
    f.month_end,
    f.segment,
    f.currency,
    f.bookings_usd as booked_usd,
    l.billed_local,
    f.billings_usd as billed_usd,
    f.unmatched_usd,
    f.unmatched_share,
    f.tie_out_status,
    false as is_total
from {{ ref('rpt_finance_month') }} f
left join local_rolled l
    on f.month_end = l.month_end
   and f.segment = l.segment
   and f.currency = l.currency
where f.currency != 'All'

union all

select
    month_key,
    month_end,
    segment,
    'Total',
    bookings_usd,
    null,
    billings_usd,
    unmatched_usd,
    unmatched_share,
    null,
    true
from {{ ref('rpt_finance_month') }}
where currency = 'All'
