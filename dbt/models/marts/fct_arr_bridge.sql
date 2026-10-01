-- Closed-month ARR bridge. Sums to fct_arr_monthly on every movement.
select
    month_end,
    segment,
    region,
    sum(opening_arr_usd) as opening_arr_usd,
    sum(arr_new_usd) as arr_new_usd,
    sum(arr_expansion_usd) as arr_expansion_usd,
    sum(arr_contraction_usd) as arr_contraction_usd,
    sum(arr_churn_usd) as arr_churn_usd,
    sum(arr_reactivation_usd) as arr_reactivation_usd,
    sum(committed_arr_usd) as committed_arr_usd
from {{ ref('fct_arr_monthly') }}
group by month_end, segment, region
