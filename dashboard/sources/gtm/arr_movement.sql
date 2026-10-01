select
    m.month_end,
    m.segment,
    m.region,
    m.master_account_id,
    a.name as account_name,
    m.arr_new_usd,
    m.arr_expansion_usd,
    m.arr_contraction_usd,
    m.arr_churn_usd,
    m.arr_reactivation_usd
from marts.fct_arr_monthly m
left join marts.dim_account a on a.account_id = m.master_account_id
