{{ config(severity='warn') }}

-- Pending review pairs above the balance materiality band (1% of committed ARR).
select
    q.account_id_a,
    q.account_id_b,
    q.arr_at_stake_usd,
    q.queue_rank
from {{ ref('dq_account_review_queue') }} q
where q.arr_at_stake_usd > (
    select sum(committed_arr_usd)
    from {{ ref('fct_arr_monthly') }}
    where month_end = (select max(month_end) from {{ ref('fct_arr_monthly') }})
) * (
    select cast(threshold_value as double)
    from {{ ref('policy_thresholds') }}
    where threshold_key = 'materiality_balance_pct'
)
