-- Account-level movements for the closed months. Top movers and drill read this.
select
    master_account_id,
    segment,
    region,
    month_end,
    opening_arr_usd,
    arr_new_usd,
    arr_expansion_usd,
    arr_contraction_usd,
    arr_churn_usd,
    arr_reactivation_usd,
    committed_arr_usd,
    committed_arr_usd - opening_arr_usd as net_movement_usd
from {{ ref('fct_arr_monthly') }}
