{{ config(severity='warn', store_failures=true) }}

-- Closed Won amount mismatches last modified within 7 days of the warehouse as-of date.
select
    record_id,
    first_seen,
    age_days,
    usd_at_stake
from {{ ref('dq_backlog') }}
where exception_type = 'closed_won_amount_line_mismatch'
  and age_days between 0 and 7
