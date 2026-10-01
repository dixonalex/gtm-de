select
    account_name,
    record_id,
    exception_type,
    opened_on,
    resolved_on,
    amount_usd,
    owner_name,
    sla_bd,
    age_days,
    past_sla,
    is_open
from marts.fct_deal_desk_exception
