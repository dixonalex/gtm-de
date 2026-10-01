select
    order_id,
    status,
    contract_value_usd,
    billed_to_date_usd,
    variance_usd
from marts.rpt_bookings_to_billings
