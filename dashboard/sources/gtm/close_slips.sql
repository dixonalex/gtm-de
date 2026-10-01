select
    opportunity_id,
    opportunity_name,
    account_name,
    previous_close_date,
    close_date,
    changed_on,
    days_slipped,
    amount_usd
from marts.fct_close_date_slip
