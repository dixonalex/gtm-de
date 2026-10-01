select
    month_end,
    bookings_usd,
    renewals_and_existing_usd,
    usage_overage_usd,
    booked_not_billed_usd,
    cancels_and_credits_usd,
    billed_without_order_usd,
    billings_usd
from marts.fct_bookings_billings_bridge
