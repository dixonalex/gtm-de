select
    opportunity_id,
    account_name,
    segment,
    owner_name,
    amount_usd,
    close_date,
    previous_close_date,
    slip_count
from marts.fct_slipped_deals
order by amount_usd desc
