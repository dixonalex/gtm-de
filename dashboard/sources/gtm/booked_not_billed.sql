select
    month_end,
    order_id,
    account_name,
    segment,
    owner_name,
    effective_date,
    amount_usd,
    age_bd,
    sla_bd
from marts.fct_booked_not_billed
