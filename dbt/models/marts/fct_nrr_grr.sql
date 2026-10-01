-- Trailing twelve-month NRR and GRR on the cohort that had ARR twelve months earlier.
with cohort as (
    select
        later.month_end,
        earlier.master_account_id,
        earlier.committed_arr_usd as starting_arr_usd,
        later.committed_arr_usd as ending_arr_usd
    from {{ ref('fct_arr_monthly') }} earlier
    inner join {{ ref('fct_arr_monthly') }} later
        on earlier.master_account_id = later.master_account_id
       and later.month_end = cast(earlier.month_end + interval 12 month as date)
    where earlier.committed_arr_usd > 0
)

select
    month_end,
    sum(starting_arr_usd) as starting_arr_usd,
    sum(ending_arr_usd) as ending_arr_usd,
    sum(least(ending_arr_usd, starting_arr_usd)) as retained_arr_usd,
    sum(ending_arr_usd) / nullif(sum(starting_arr_usd), 0) as nrr,
    sum(least(ending_arr_usd, starting_arr_usd)) / nullif(sum(starting_arr_usd), 0) as grr
from cohort
group by month_end
