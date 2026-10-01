select
    opportunity_id,
    month_end,
    master_account_id,
    stage_name,
    forecast_category,
    close_date,
    amount_usd
from marts.fct_pipeline_snapshot
