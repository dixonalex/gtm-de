-- Weekly call scaled to the slice's commit, so week 13 is that slice and not the company line.
with company as (
    select week_index, commit_usd
    from {{ ref('fct_forecast_call') }}
    where week_index = 13
),

call as (
    select week_index, week_start, commit_usd, best_case_usd
    from {{ ref('fct_forecast_call') }}
)

select
    a.segment,
    a.team,
    a.rep,
    c.week_index,
    c.week_start,
    c.commit_usd * a.commit_usd / nullif(k.commit_usd, 0) as commit_usd,
    c.best_case_usd * a.commit_usd / nullif(k.commit_usd, 0) as best_case_usd,
    a.quota_usd
from call c
cross join {{ ref('rpt_sales_attainment') }} a
cross join company k
