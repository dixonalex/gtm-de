{{ config(severity='warn') }}

-- Closed Won without an order, older than 30 days, with more than $25k at stake.
select
    record_id,
    first_seen,
    age_days,
    usd_at_stake
from {{ ref('dq_backlog') }}
where exception_type = 'closed_won_without_order'
  and age_days > 30
  and usd_at_stake > 25000
