select
    snapshot_date,
    open_count,
    open_amount_usd,
    past_sla_count,
    past_sla_amount_usd,
    breach_tomorrow_count,
    breach_tomorrow_amount_usd
from marts.fct_deal_desk_daily
