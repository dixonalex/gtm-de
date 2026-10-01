-- Opening + new + expansion + contraction + churn + reactivation equals closing ARR.
select
    master_account_id,
    month_end,
    opening_arr_usd,
    arr_new_usd,
    arr_expansion_usd,
    arr_contraction_usd,
    arr_churn_usd,
    arr_reactivation_usd,
    committed_arr_usd
from {{ ref('fct_arr_monthly') }}
where abs(
    opening_arr_usd
    + arr_new_usd
    + arr_expansion_usd
    + arr_contraction_usd
    + arr_churn_usd
    + arr_reactivation_usd
    - committed_arr_usd
) > 0.01
