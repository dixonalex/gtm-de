select
    object_name,
    strftime(max_loaded_at, '%Y-%m-%d %H:%M') || ' UTC' as max_loaded_at,
    age_hours,
    sla,
    status
from dq.dq_row_arrival_freshness
