{{ config(severity='warn') }}

-- Pending review pairs whose combined committed ARR is above $50k.
select
    account_id_a,
    account_id_b,
    arr_at_stake_usd,
    queue_rank
from {{ ref('dq_account_review_queue') }}
where arr_at_stake_usd > 50000
