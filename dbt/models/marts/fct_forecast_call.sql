-- Weekly commit and best-case call. The path is the scripted forecast, not the open pipeline.
select
    cast(week_start as date) as week_start,
    cast(week_index as integer) as week_index,
    cast(commit_usd as double) as commit_usd,
    cast(best_case_usd as double) as best_case_usd
from {{ ref('forecast_call_weekly') }}
