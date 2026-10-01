-- Deal Desk queue. Open rows are the worklist; resolved rows support the last-7-days stats.
-- age_days is stored on the extract so the median (1.6) is not forced onto integer business days.
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
    age_days > sla_bd as past_sla,
    resolved_on is null as is_open
from {{ ref('stg_story__deal_desk_exception') }}
