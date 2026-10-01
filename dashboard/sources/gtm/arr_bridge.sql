select
    month_end,
    segment,
    region,
    opening_arr_usd,
    arr_new_usd,
    arr_expansion_usd,
    arr_contraction_usd,
    arr_churn_usd,
    arr_reactivation_usd,
    committed_arr_usd
from marts.fct_arr_bridge
