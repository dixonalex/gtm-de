select
    master_account_id,
    ultimate_parent_account_id,
    month_end,
    seats_arr_usd,
    support_arr_usd,
    commit_arr_usd,
    committed_arr_usd,
    usage_overage_run_rate_usd,
    opening_arr_usd,
    arr_new_usd,
    arr_expansion_usd,
    arr_contraction_usd,
    arr_churn_usd,
    arr_reactivation_usd
from marts.fct_arr_monthly
