-- Actual ARR and net new against the derived plan. Gaps are actual minus plan.
with actual as (
    select
        month_end,
        segment,
        sum(committed_arr_usd) as arr_usd,
        sum(arr_new_usd + arr_expansion_usd + arr_contraction_usd + arr_churn_usd + arr_reactivation_usd) as net_new_usd
    from {{ ref('fct_arr_monthly') }}
    group by month_end, segment
)

select
    a.month_end,
    a.segment,
    a.arr_usd,
    p.arr_usd as arr_plan_usd,
    a.arr_usd - p.arr_usd as arr_gap_usd,
    a.net_new_usd,
    p.net_new_usd as net_new_plan_usd,
    a.net_new_usd - p.net_new_usd as net_new_gap_usd,
    p.nrr_plan,
    p.grr_plan
from actual a
inner join {{ ref('plan_monthly') }} p
    on a.month_end = p.month_end
   and a.segment = p.segment
