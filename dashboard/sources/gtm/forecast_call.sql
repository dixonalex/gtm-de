select week_start, week_index, commit_usd, best_case_usd
from marts.fct_forecast_call
order by week_index
