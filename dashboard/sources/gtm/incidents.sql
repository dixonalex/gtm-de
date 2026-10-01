select
    i.incident_key,
    i.title,
    i.impact,
    i.action,
    i.owner,
    i.sla_hours,
    date_diff('hour', i.opened_at, c.now) as age_hours
from seeds.dq_incidents i
cross join staging.stg_fivetran_log__extract_clock c
