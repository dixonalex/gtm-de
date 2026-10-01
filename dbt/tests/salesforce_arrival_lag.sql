{{ config(severity='warn', store_failures=true) }}

-- Late Salesforce rows loaded within 7 days of the warehouse as-of date.
select
    record_id,
    first_seen,
    age_days
from {{ ref('dq_backlog') }}
where exception_type = 'salesforce_arrival_lag'
  and age_days between 0 and 7
