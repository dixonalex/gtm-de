{{ config(severity='warn') }}

-- Pending review queue larger than 100 pairs.
select count(*) as queue_size
from {{ ref('dq_account_review_queue') }}
having count(*) > 100
