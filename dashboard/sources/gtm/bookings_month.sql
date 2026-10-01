select
    b.month_end,
    b.segment,
    b.bookings_acv_usd,
    p.bookings_usd as bookings_plan_usd
from marts.fct_bookings_monthly b
left join seeds.plan_monthly p
    on b.month_end = p.month_end
   and b.segment = p.segment
