-- Bookings-to-billings for the latest closed month.
-- renewals_and_existing is the plug so the two ends tie. The other legs are measured.
with closed as (
    select max(month_end) as month_end
    from {{ ref('close_calendar') }}
    where close_date <= {{ as_of_date() }}
),

bounds as (
    select
        month_end,
        cast(date_trunc('month', month_end) as date) as month_start
    from closed
),

bookings as (
    select coalesce(sum(bookings_acv_usd), 0) as amount_usd
    from {{ ref('fct_bookings') }} b
    cross join bounds d
    where b.booking_type in ('new', 'expansion')
      and b.booking_date between d.month_start and d.month_end
),

billings as (
    select
        coalesce(sum(billed_usd), 0) as amount_usd,
        coalesce(sum(billed_usd) filter (where is_overage), 0) as overage_usd,
        coalesce(sum(billed_usd) filter (where order_id is null), 0) as billed_without_order_usd,
        coalesce(sum(-billed_usd) filter (where billed_usd < 0), 0) as cancels_and_credits_usd
    from {{ ref('fct_billings') }} b
    cross join bounds d
    where b.invoice_date between d.month_start and d.month_end
),

bnb as (
    select coalesce(sum(amount_usd), 0) as amount_usd
    from {{ ref('fct_booked_not_billed') }} n
    cross join closed c
    where n.month_end = c.month_end
),

legs as (
    select
        c.month_end,
        k.amount_usd as bookings_usd,
        g.overage_usd as usage_overage_usd,
        n.amount_usd as booked_not_billed_usd,
        g.cancels_and_credits_usd,
        g.billed_without_order_usd,
        g.amount_usd as billings_usd
    from closed c
    cross join bookings k
    cross join billings g
    cross join bnb n
)

select
    month_end,
    bookings_usd,
    billings_usd
        - bookings_usd
        - usage_overage_usd
        + booked_not_billed_usd
        + cancels_and_credits_usd
        - billed_without_order_usd as renewals_and_existing_usd,
    usage_overage_usd,
    booked_not_billed_usd,
    cancels_and_credits_usd,
    billed_without_order_usd,
    billings_usd
from legs
