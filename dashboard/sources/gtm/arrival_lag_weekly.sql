select
    object_name,
    week_start,
    row_count,
    p50_lag_hours,
    p95_lag_hours
from dq.dq_arrival_lag_weekly
