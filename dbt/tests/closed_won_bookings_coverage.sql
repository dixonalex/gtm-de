-- Every Closed Won opportunity is booked or listed as an exception with a reason.
select o.opportunity_id
from {{ ref('stg_salesforce__opportunity') }} o
where o.is_won
  and not exists (
      select 1
      from {{ ref('fct_bookings') }} b
      where b.opportunity_id = o.opportunity_id
  )
  and not exists (
      select 1
      from {{ ref('rpt_quote_to_cash_exceptions') }} e
      where e.entity_id = o.opportunity_id
        and e.exception_type is not null
  )
