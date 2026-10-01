{{ config(severity='warn', store_failures=true) }}

-- Warns while any Closed Won opportunity has no order.
select
    entity_id,
    account_id,
    master_account_id,
    invoiced_anyway
from {{ ref('rpt_quote_to_cash_exceptions') }}
where exception_type = 'closed_won_without_order'
